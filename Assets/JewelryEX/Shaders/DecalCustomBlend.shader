Shader "Custom/DecalCustomBlend"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        // デカール用のタグ指定
        Tags { "RenderType"="Decal" "Decal"="true" "Queue"="Transparent+1" }
        LOD 200

        Pass
        {
            Name "DecalForward"
            Tags { "LightMode"="UniversalForward" }
            
            // ブレンディング状態（ここで必要に応じてカスタムブレンドを記述）
            Blend SrcAlpha OneMinusSrcAlpha  
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // fog 用のマクロ（必要なら）
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 vertex   : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 position : SV_POSITION;
                float2 uv       : TEXCOORD0;
                // UNITY_FOG_COORDS(1)
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.position = TransformObjectToHClip(IN.vertex.xyz);
                OUT.uv       = IN.texcoord;
                // UNITY_TRANSFER_FOG(OUT, OUT.position);
                return OUT;
            }
            
CBUFFER_START(UnityPerMaterial)
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            half4 _BaseColor;
CBUFFER_END

            // カスタムブレンディング関数（例: alpha に応じた線形補間）
            float4 frag(Varyings IN) : SV_Target
            {
                // テクスチャと基本色を掛け合わせる
                float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                float4 decalColor = texColor * _BaseColor;

                // ここでカスタムブレンディングのロジックを実装可能
                // 例えば、既存の色（背景カラーなど）との補間を行う場合：
                // float3 background = float3(0,0,0); // 例として背景を黒に固定
                // decalColor.rgb = lerp(background, decalColor.rgb, decalColor.a);
                //
                // ※実際には被写体（下層オブジェクト）の色をサンプラーで取得するなどの方法も考えられます。

                // UNITY_APPLY_FOG(IN, decalColor);
                return decalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Decal"
}