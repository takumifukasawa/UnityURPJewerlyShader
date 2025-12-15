Shader "Outline/OutlineEnv"
{
    Properties
    {
        _OutlineColor("OutlineColor", Color) = (0, 0, 0, 1)
        _OutlineWidth("OutlineWidth", Range(0, 0.1)) = 0.01
        _OutlineDepthOffset("OutlineDepthOffset", Range(-.01, .01)) = 0.01
        _OutlineEnvCoefficient("OutlineEnvCoefficient", Range(0, 1)) = 0.5
    }

    SubShader
    {
        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel"="4.5"}
        LOD 300
       
        Pass
        {
            Name "ForwardLitOutline"
        
            Cull Front

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float4 worldPosition : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
            };

            half4 _OutlineColor;
            float _OutlineWidth;
            float _OutlineDepthOffset;
            float _OutlineEnvCoefficient;
            
            v2f vert (appdata v)
            {
                v2f o = (v2f)0;

                float4 viewPos = mul(UNITY_MATRIX_MV, float4(v.vertex.xyz, 1.));

                float3 normalLocal = v.normal;
                
                float3 normalWorld = mul((float3x3)unity_ObjectToWorld, normalLocal);
                float3 normalView = mul((float3x3)unity_WorldToCamera, normalWorld);
                
                float4 normalView4 = float4(normalView, 0.0);
                float4 normalClip = mul(UNITY_MATRIX_P, normalView4);

                o.position = UnityViewToClipPos(viewPos);
                o.position += normalClip * float4(_OutlineWidth, _OutlineWidth, _OutlineWidth, 0.0);
                o.position.z += _OutlineDepthOffset;

                o.worldNormal = normalWorld;

                float4 reconstructViewPos = mul(unity_CameraInvProjection, o.position);
                reconstructViewPos.xyz /= reconstructViewPos.w;
                float4 reconstructWorldPos = mul(unity_CameraToWorld, reconstructViewPos);

                o.worldPosition = reconstructWorldPos;
             
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);

                half3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPosition);
                half3 reflDir = reflect(-worldViewDir, i.worldNormal);
                float3 envDiffuse = ShadeSH9(float4(worldNormal, 1.));
                float3 envSpecular = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 0.0).xyz;
                fixed4 color = fixed4((envDiffuse + envSpecular) * _OutlineEnvCoefficient, 1.);
                color += _OutlineColor;
                return color;
            }
            
            ENDCG
        }
    }
}
