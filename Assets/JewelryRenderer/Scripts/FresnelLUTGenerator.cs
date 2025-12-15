using UnityEngine;

namespace Jewelry
{
    public class FresnelLUTGenerator : MonoBehaviour
    {
        [Header("Fresnel LUT Settings")]
        [Tooltip("物体のIOR（Index of Refraction）。空気の場合は1。通常は1より大きい値を使用します。")]
        [SerializeField]
        private float materialIOR = 1.45f;

        [Tooltip("内積の値の分解能。例えば256なら横幅が256で、256段階で分解します。")]
        [SerializeField]
        private int resolution = 256;

        // 生成したLUTテクスチャ（必要に応じて他スクリプトから参照できるようにpublicにしています）
        [HideInInspector]
        public Texture2D fresnelLUT;

        private void Awake()
        {
            GenerateFresnelLUT();
        }

        /// <summary>
        /// 指定された解像度に基づいてFresnel LUTテクスチャを生成する
        /// </summary>
        private void GenerateFresnelLUT()
        {
            // 横幅: resolution, 縦幅: 1 のテクスチャを作成
            // ここではRFloat形式を使用していますが、必要に応じてRGBA32等に変更できます
            fresnelLUT = new Texture2D(resolution, 1, TextureFormat.RFloat, false);
            fresnelLUT.wrapMode = TextureWrapMode.Clamp;
            fresnelLUT.filterMode = FilterMode.Bilinear;

            // Schlickの近似式でFresnelの基礎値F0を計算
            // F0 = ((n1 - n2)/(n1 + n2))^2 とし、n1（空気）を1、n2をmaterialIORとします。
            float F0 = Mathf.Pow((1.0f - materialIOR) / (1.0f + materialIOR), 2.0f);

            // 各ピクセルについて内積に応じたFresnel値を計算して設定
            for (int x = 0; x < resolution; x++)
            {
                // 内積（cos(theta)）の値を0～1の範囲で計算
                float dot = (float)x / (resolution - 1);

                // Schlickの近似式:
                // Fresnel = F0 + (1 - F0) * (1 - cos(theta))^5
                float fresnel = F0 + (1.0f - F0) * Mathf.Pow(1.0f - dot, 5.0f);

                // グレースケールの色として値を設定（RGB全てに同じ値）
                Color col = new Color(fresnel, fresnel, fresnel, 1.0f);
                fresnelLUT.SetPixel(x, 0, col);
            }

            // テクスチャに変更を適用
            fresnelLUT.Apply();
        }
    }
}