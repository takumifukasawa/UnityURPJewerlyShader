Shader "CubemapBaker/Normal"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "DisableBatching"="True" }
        LOD 100
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex   vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
            };

            float4 _Centroid;
            float _BoundsScale;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // xy: 法線のxyのみpackする
                float2 xy = saturate(i.normal.xy * .5 + .5);
                // z: 中心からの距離
                float z = length(i.vertex.xyz);
                // w: boundsの逆数. boundsは均等な大きさに制限
                float w = 1. / _BoundsScale;
                w = 1.;
                return fixed4(xy, z, w);
            }
            ENDCG
        }
    }
}
