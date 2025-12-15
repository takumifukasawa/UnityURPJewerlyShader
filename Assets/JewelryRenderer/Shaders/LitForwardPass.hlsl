// ORIGINAL_BEGIN
// #ifndef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
// #define UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
// ORIGINAL_END

// CUSTOM_BEGIN
#ifndef JEWELRY_FORWARD_LIT_PASS_INCLUDED
#define JEWELRY_FORWARD_LIT_PASS_INCLUDED

// config
#define NORMAL_XY
// #define RGB_SPECTROSCOPY

#include "Assets/JewelryRenderer/Shaders/Lighting.hlsl"

#define MAX_BONE_COUNT 56

samplerCUBE _NormalCubeMap;
float4 _CenterOffset;
float _IOR;
float _IterateNum;
float _SpectroscopyR;
float _SpectroscopyG;
float _SpectroscopyB;
float _AdsorptionR;
float _AdsorptionG;
float _AdsorptionB;
float _Specular;
float _EachPathDistAdjust;
float3 _LightDir_0;
half4 _LightColor_0;
float _LightMultiplier_0;
float _LightReflection_0;
float3 _LightDir_1;
half4 _LightColor_1;
float _LightMultiplier_1;
float _LightReflection_1;
// float4x4 _BindPoseMatrices[MAX_BONE_COUNT];
// float4x4 _InverseWorldMatrices[MAX_BONE_COUNT];
float4x4 _BoneMatrices[MAX_BONE_COUNT];
float4x4 _InverseBoneMatrices[MAX_BONE_COUNT];
float _FresnelPower;
float _FresnelBlendRate;

half4 GetEnvColor(float3 dir, half mip)
{
	half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, dir, mip);
	half3 irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
	return half4(irradiance, 1.);
}
    
float Fresnel(float3 inDir, float3 normal, float refractive)
{
    float f0 = pow((refractive - 1) / (refractive + 1), 2);
    float f = f0 + (1 - f0) * pow(1 - dot(-inDir, normal), 5);
    return saturate(f);
}

half4 ApplyLightDiffuse(
    float3 normal,
    float4 lightColor, float3 lightDir, float lightMultiplier
)
{
    float3 L = normalize(lightDir);
    // float diffuse = saturate(dot(normal, L)) * .5 + .5; // half lambert
    float diffuse = saturate(dot(normal, L));
    half4 diffuseColor = lightColor * diffuse * lightMultiplier;
    return diffuseColor;
}

half4 ApplyLightSpecular(
    float3 position, float3 normal, float3 eyePosition,
    float specularPower,
    float4 lightColor, float3 lightDir, float lightMultiplier
)
{
    float3 L = normalize(lightDir);
    float3 PtoE = normalize(eyePosition - position);
    float3 H = normalize(L + PtoE);
    float specular = pow(saturate(dot(normal, H)), specularPower);
    half4 specularColor = lightColor * specular * lightMultiplier;
    return specularColor;
}

// 全反射なら1, 屈折なら0
float CheckReflect(float3 I, float3 N, float eta)
{
    // 入射ベクトルと法線の間の角度を計算
    float cosThetaI = dot(-I, N);
    float sinThetaI2 = 1.0 - cosThetaI * cosThetaI;
    float eta2 = eta * eta;
    return eta2 * sinThetaI2 > 1.0 ? 1.0 : 0.0;
}

// 全反射と屈折を出し分け
float3 RefrafVector(float3 I, float3 N, float eta, out float isReflect) {
    // 全反射の条件をチェック
    if (CheckReflect(I, N, eta) > .5) {
        // 全反射が発生する場合、反射ベクトルを返す
        // return float3(1., 0., 0.);
        isReflect = 1.;
        return reflect(I, N);
    } else {
        // 全反射が発生しない場合、屈折ベクトルを計算
        // return float3(0., 0., 1.);
        isReflect = 0.;
        return refract(I, N, eta);
    }
}

half4 CastRay(
    float3 inPos,
    float3 inDir,
    float3 normal,
    uint4 boneIndices,
    float4 boneWeights,
    float3 center,
    float refractive,
    float adsorption,
    out float3 outDir,
    out float3 outPos,
    out float3 outNormal,
    inout float outAccDist,
    inout float outWeight,
    out float isReflect
)
{
    isReflect = 0.;

    float3 localInPos;
    float3 localInDir;

#if _MESH_SKINNING
        // ローカル座標系に直す
        // 完全な逆ではないことに注意
        float4x4 invSkinningMatrix =
            _InverseBoneMatrices[boneIndices.x] * boneWeights.x +
            _InverseBoneMatrices[boneIndices.y] * boneWeights.y +
            _InverseBoneMatrices[boneIndices.z] * boneWeights.z +
            _InverseBoneMatrices[boneIndices.w] * boneWeights.w;
        localInPos = mul(invSkinningMatrix, float4(inPos, 1.));
        localInDir = normalize(mul(invSkinningMatrix, inDir).xyz);
#else
        localInPos = TransformWorldToObject(inPos);
        localInDir = TransformWorldToObjectDir(inDir);
#endif
    
    float3 localCenter = TransformWorldToObject(center);

    float3 localInPToLocalCenter = localCenter - localInPos;

    // ローカル座標系での射出位置・方向
    float3 localInPosToLocalOutPos = dot(localInDir, localInPToLocalCenter) * 2 * localInDir;
    float3 localCenterToLocalOutPos = localInPosToLocalOutPos - localInPToLocalCenter;
    float3 localOutDir = normalize(localCenterToLocalOutPos);

    float4 normalCubeColor = texCUBElod(_NormalCubeMap, float4(localOutDir.xyz, 0.));

    // 法線の計算
#ifdef NORMAL_XY
    // xyの2軸から法線を再計算
    float2 decodedNormalXY = normalCubeColor.xy * 2. - 1.;
    float decodedZ = sqrt(max(0., 1. - dot(decodedNormalXY, decodedNormalXY)));
    float3 localOutNormal = normalize(float3(decodedNormalXY, decodedZ));
#else
    float3 localOutNormal = (cubeColor.xyz * 2. - 1.);
#endif

#if _MESH_SKINNING
    float4x4 skinningMatrix =
        _BoneMatrices[boneIndices.x] * boneWeights.x +
        _BoneMatrices[boneIndices.y] * boneWeights.y +
        _BoneMatrices[boneIndices.z] * boneWeights.z +
        _BoneMatrices[boneIndices.w] * boneWeights.w;
    outPos = inPos + normalize(mul(skinningMatrix, localOutNormal));
    outNormal = normalize(mul(skinningMatrix, localOutNormal));
#else
    // 射出位置
    outPos = inPos + TransformObjectToWorldDir(localInPosToLocalOutPos);
    // 射出方向(外側を向く)
    outNormal = TransformObjectToWorldNormal(localOutNormal);
#endif

    float3 inwardFacingNormal = -outNormal;

    outDir = RefrafVector(inDir, inwardFacingNormal, refractive, isReflect);
    float fr = Fresnel(inDir, inwardFacingNormal, refractive);
#if _REFLECT_FRESNEL_WEIGHT_ENABLED
    outWeight *= fr; // 反射する量をweightにかけて残す = フレネル分をweightにかける
    outWeight = saturate(outWeight);
#endif

    float3 reflDir = normalize(reflect(inDir, inwardFacingNormal));
    float3 refrDir = normalize(refract(inDir, inwardFacingNormal, refractive));

    half4 reflEnvColor = GetEnvColor(reflDir, 0.);
    half4 refrEnvColor = GetEnvColor(refrDir, 0.);

    half4 envColor = lerp(refrEnvColor, reflEnvColor, fr);

    float inToOutDist = length(outPos - inPos);
    outAccDist += inToOutDist;

#ifdef _ADSORPTION_TOTAL_DIST
    float attenuation = exp(-outAccDist * adsorption);
#else
    float attenuation = exp(-inToOutDist * adsorption * _EachPathDistAdjust);
#endif
    
    half4 color = envColor * attenuation * outWeight;

    // NOTE: 光源の計算にもweightかけるべき？
    color += ApplyLightDiffuse(
        outDir,
        _LightColor_0, _LightDir_0, _LightMultiplier_0
    ) * attenuation;
    color += ApplyLightDiffuse(
        outDir,
        _LightColor_1, _LightDir_1, _LightMultiplier_1
    ) * attenuation;

    // for debug
    // outDir = localOutNormal;
    // outDir = outPos;
    // // outDir = normal;
    // outDir = inPos;
    // outDir = localInPos;
    // outDir = localOutDir;
    // outDir = outPos;
    // outDir = outNormal;

    return color;
}

void CastRayIterate(
    float3 inPos,
    float3 inDir,
    float3 normal,
    uint4 boneIndices,
    float4 boneWeights,
    float3 center,
    float ior,
    float spectroscopy,
    float adsorption,
    out half4 outColor,
    out float3 outDir,
    out float3 outPos,
    out float3 outNormal
)
{
    // initialize
    outColor = half4(0, 0, 0, 1);
    outDir = normalize(inDir);
    outPos = inPos;
    outNormal = normal;

    float outWeight = 1.;

    float3 _inPos = inPos;
    float3 _inDir = inDir;
    float isReflect = 1.;
    half4 accColor = half4(0, 0, 0, 1);

    // 最初の進入時は屈折
    _inDir = refract(inDir, normal, ior + spectroscopy);
    outDir = _inDir;

    float outAccDist = 0.;

    for (int i = 0; i < _IterateNum; i++)
    {
        if (isReflect)
        {
            accColor += CastRay(
                _inPos, _inDir, normal, boneIndices, boneWeights,
                center, 1. / (ior + spectroscopy), adsorption,
                outDir, outPos, outNormal, outAccDist, outWeight, isReflect
            );
        }
        _inPos = outPos;
        _inDir = outDir;
    }

    outColor = accColor;
}

// CUSTOM_END

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

// keep this file in sync with LitGBufferPass.hlsl

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 staticLightmapUV   : TEXCOORD1;
    float2 dynamicLightmapUV  : TEXCOORD2;
    // CUSTOM_BEGIN
    float4 boneWeights : BLENDWEIGHTS;
    uint4 boneIndices : BLENDINDICES;
    // CUSTOM_END
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    float3 positionWS               : TEXCOORD1;
#endif

    float3 normalWS                 : TEXCOORD2;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    half4 tangentWS                : TEXCOORD3;    // xyz: tangent, w: sign
#endif
    float3 viewDirWS                : TEXCOORD4;

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half4 fogFactorAndVertexLight   : TEXCOORD5; // x: fogFactor, yzw: vertex light
#else
    half  fogFactor                 : TEXCOORD5;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD6;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS                : TEXCOORD7;
#endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
#ifdef DYNAMICLIGHTMAP_ON
    float2  dynamicLightmapUV : TEXCOORD9; // Dynamic lightmap UVs
#endif

    // CUSTOM
    float4 boneWeights : TEXCOORD10;
    uint4 boneIndices : TEXCOORD11;

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = input.positionWS;
#endif

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
#if defined(_NORMALMAP) || defined(_DETAIL)
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

    #if defined(_NORMALMAP)
    inputData.tangentToWorld = tangentToWorld;
    #endif
    inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
#else
    inputData.normalWS = input.normalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
#else
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
#endif

#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
#endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.dynamicLightmapUV = input.dynamicLightmapUV;
    #endif
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.vertexSH;
    #endif
    #endif
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);

    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
        fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
#endif

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
#else
    output.fogFactor = fogFactor;
#endif

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;

    // CUSTOM
    output.boneWeights = input.boneWeights;
    output.boneIndices = input.boneIndices;
    // float4x4 sm =
    //     _BoneMatrices[input.boneIndices.x] * input.boneWeights.x +
    //     _BoneMatrices[input.boneIndices.y] * input.boneWeights.y +
    //     _BoneMatrices[input.boneIndices.z] * input.boneWeights.z +
    //     _BoneMatrices[input.boneIndices.w] * input.boneWeights.w;
    // float3 ws = mul(sm, input.positionOS);
    // float cs  = TransformWorldToHClip(ws);
    // output.positionWS = ws;
    // output.positionCS = cs;

    return output;
}

// Used in Standard (Physically Based) shader
half4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    
// ORIGINAL_BEGIN
// #if defined(_PARALLAXMAP)
// #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
//     half3 viewDirTS = input.viewDirTS;
// #else
//     half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
//     half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
// #endif
//     ApplyPerPixelDisplacement(viewDirTS, input.uv);
// #endif
// 
//     SurfaceData surfaceData;
//     InitializeStandardLitSurfaceData(input.uv, surfaceData);
// 
//     InputData inputData;
//     InitializeInputData(input, surfaceData.normalTS, inputData);
//     SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);
// 
// #ifdef _DBUFFER
//     ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
// #endif
// 
//     half4 color = UniversalFragmentPBR(inputData, surfaceData);
// 
//     color.rgb = MixFog(color.rgb, inputData.fogCoord);
//     color.a = OutputAlpha(color.a, _Surface);
// ORIGINAL_END

    // CUSTOM_BEGIN
    half4 outColor = half4(0, 0, 0, 1);

    float3 E = _WorldSpaceCameraPos;
    float3 P = input.positionWS;
    float3 N = normalize(input.normalWS);
    float3 PtoE = normalize(E - P);
    float3 inDir = -PtoE;

    float3 inPos = P;

    float3 outDir;
    float3 outPos;
    float3 outNormal;

    float ior = 1. / _IOR;

    float fr = Fresnel(inDir, N, _IOR);
    fr = pow(fr, _FresnelPower);
    fr *= _FresnelBlendRate;

    // 全反射
    float3 R = reflect(inDir, N);

    // フレネルをもとにprobeの色を計算
    half4 envColor = GetEnvColor(R, 0);

    float3 center = unity_ObjectToWorld._m03_m13_m23 + _CenterOffset.xyz;

#ifdef _SPECTROSCOPY_RGB
    half4 outColorR;
    half4 outColorG;
    half4 outColorB;
    CastRayIterate(
        inPos, inDir, N, input.boneIndices, input.boneWeights,
        center, ior, _SpectroscopyR, _AdsorptionR,
        outColorR, outDir, outPos, outNormal
    );
    CastRayIterate(
        inPos, inDir, N, input.boneIndices, input.boneWeights,
        center, ior, _SpectroscopyG, _AdsorptionG,
        outColorG, outDir, outPos, outNormal
    );
    CastRayIterate(
        inPos, inDir, N, input.boneIndices, input.boneWeights,
        center, ior, _SpectroscopyB, _AdsorptionB,
        outColorB, outDir, outPos, outNormal
    );
    outColor.x = outColorR.x;
    outColor.y = outColorG.y;
    outColor.z = outColorB.z;
#else
    float adsorption = (_AdsorptionR + _AdsorptionG + _AdsorptionB) * .33;
    CastRayIterate(
        inPos, inDir, N, input.boneIndices, input.boneWeights,
        center, _IOR, 0, adsorption,
        outColor, outDir, outPos, outNormal
    );
#endif

    outColor.xyz = max(half3(0, 0, 0), outColor.xyz);

    // // 進入時のフレネルに応じてブレンド
    outColor = half4(lerp(outColor.xyz, envColor.xyz, fr), 1.);

    // // 全反射のspecularをブレンド
    // // TODO: fresnelを考慮したほうがよい？
    // outColor += ApplyLightSpecular(
    //     inPos, N, E,
    //     _Specular,
    //     _LightColor_0, _LightDir_0, _LightMultiplier_0
    // ) * _LightReflection_0 * fr;
    // outColor += ApplyLightSpecular(
    //     inPos, N, E,
    //     _Specular,
    //     _LightColor_1, _LightDir_1, _LightMultiplier_1
    // ) * _LightReflection_1 * fr;

    // for debug
    // outColor = float4(outDir, 1.);
    // outColor = float4(input.boneWeight.xyz, 1);
    // outColor = float4(outDir, 1.);
    // outColor = envColor;
    // outColor.xyz = fr;
    // outColor.xyz = envColor.xyz;
    // outColor.xyz = R;

    // color.xyz = dot(outDir, outDir);
    // color.xyz = GetEnvColor(outDir, 0);
    // // color.xyz = inDir;
    // // color.xyz = outNormal;
    // color.xyz = outDir;
    // color = outColor;
    // CUSTOM_END

    return outColor;
}

#endif