/*
// manually
Shader "Jewelry/DebugReflection"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _CubeMap ("EnvCubeMap", Cube) = "white" {}
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"

            struct CustomAttributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct CustomVaryings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                samplerCUBE _CubeMap;
            CBUFFER_END

            CustomVaryings vert(CustomAttributes IN)
            {
                CustomVaryings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 frag(CustomVaryings IN) : SV_Target
            {
                half4 outColor = half4(0, 0, 0, 1);

                float3 E = _WorldSpaceCameraPos;
                float3 P = IN.positionWS;
                float3 N = normalize(IN.normalWS);
                float3 PtoE = normalize(E - P);
                float3 R = reflect(-PtoE, N);

                outColor.xyz = texCUBE(_CubeMap, normalize(R)) * _Color;

                return outColor;
            }
            ENDHLSL
        }
    }
}
*/

// chat gpt test
Shader "Jewelry/DebugReflection" {
// Shader "Custom/EnvMapManualNoSurf" {
    Properties {
        // 基本テクスチャ（アルベド）
        _MainTex ("Base Texture", 2D) = "white" {}
        // 環境マップ（キューブマップ）
        _Cube ("Environment Cubemap", Cube) = "" {}
        // 反射率（0～1の範囲）
        _Reflectivity ("Reflectivity", Range(0,1)) = 0.5
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass {
            CGPROGRAM
            // 通常の頂点シェーダーとピクセルシェーダーを使用
            #pragma vertex vert
            #pragma fragment frag

            // Unityの共通ヘッダーをインクルード
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            samplerCUBE _Cube;
            float _Reflectivity;

            // 頂点属性構造体
            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            // 頂点シェーダーからピクセルシェーダーへ送るデータ構造体
            struct v2f {
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            // 頂点シェーダー
            v2f vert (appdata v) {
                v2f o;
                // クリップ空間での頂点位置を計算
                o.vertex = UnityObjectToClipPos(v.vertex);
                // ワールド空間での頂点位置を計算
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                // ワールド空間での法線を計算（正規化も実施）
                o.worldNormal = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));
                o.uv = v.uv;
                return o;
            }

            // ピクセル（フラグメント）シェーダー
            fixed4 frag (v2f i) : SV_Target {
                // 基本テクスチャから色をサンプリング
                fixed4 baseColor = tex2D(_MainTex, i.uv);

                // カメラからの視線方向を計算（_WorldSpaceCameraPosはUnityの組み込み変数）
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // 反射ベクトルの計算:
                // reflect(入射方向, 法線) は入射方向の反対からの反射を返すため、-viewDirを利用
                float3 reflectionVec = reflect(-viewDir, normalize(i.worldNormal));

                // 環境マップ（キューブマップ）から反射色をサンプリング
                fixed4 envColor = texCUBE(_Cube, reflectionVec);

                // 基本テクスチャの色と環境マップの反射色を、反射率(_Reflectivity)で補間して合成
                fixed4 finalColor;
                finalColor.rgb = lerp(baseColor.rgb, envColor.rgb, _Reflectivity);
                finalColor.a = baseColor.a;

                return finalColor;
            }
            ENDCG
        }
    }
    // シェーダーが利用できない場合のフォールバックとしてDiffuseを指定
    FallBack "Diffuse"
}
