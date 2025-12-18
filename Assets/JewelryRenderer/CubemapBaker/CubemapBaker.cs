// #define SAVE_MATERIAL

using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.Rendering;


namespace JewelryRenderer
{
#if UNITY_EDITOR
    [ExecuteInEditMode]
    public class CubemapBaker : MonoBehaviour
    {
#pragma warning disable CS0414
        private static readonly string bakerShaderName = "CubemapBaker/Default";
#pragma warning restore CS0414

        public GameObject cameraPrefab = null;
        public GameObject meshPrefab = null;
        public bool manualCentroid = false;
        public Vector3 centroid = Vector3.zero;
        public bool sRGBEnabled = false;
        public TextureImporterFormat textureFormat = TextureImporterFormat.RGBA32;
        public int width = 256;
        public float boundsScale = 1f;

        // public void Bake(string cubemapPath, string materialPath)
        public void Bake(string cubemapPath)
        {
            var activeObjects = UnactivateAll();

            var destroyables = new Stack<UnityEngine.Object>();
            try
            {
                var meshObj = Instantiate(this.meshPrefab);
                meshObj.SetActive(true);
                destroyables.Push(meshObj);

                var cameraObj = Instantiate(this.cameraPrefab);
                cameraObj.SetActive(true);
                destroyables.Push(cameraObj);

                var renderer = meshObj.GetComponent<Renderer>();
                var mesh = renderer is MeshRenderer ? meshObj.GetComponent<MeshFilter>().sharedMesh : renderer is SkinnedMeshRenderer smr ? smr.sharedMesh : null;
                var camera = cameraObj.GetComponent<Camera>();

                var c = this.centroid;
                if (!this.manualCentroid) c = GetCentroid(mesh);
                InitCamera(camera, renderer, c);

                var bakerMaterial = new Material(Shader.Find(CubemapBaker.bakerShaderName));
                destroyables.Push(bakerMaterial);
                InitBakerMaterial(bakerMaterial, renderer);

                var cubemap = new Cubemap(this.width, GraphicsFormat.R8G8B8A8_UNorm, TextureCreationFlags.None);
                destroyables.Push(cubemap);
                InitCubemap(cubemap);

                Render(renderer, camera, bakerMaterial, cubemap);
                SaveTexture(cubemap, cubemapPath);
                SaveImporter(cubemapPath);
#if SAVE_MATERIAL
                SaveMaterial(materialPath, cubemapPath, c);
#endif
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();
            }
            finally
            {
                foreach (var obj in destroyables) DestroyImmediate(obj);
                ActivateAll(activeObjects);
            }
        }

        private IEnumerable<GameObject> UnactivateAll()
        {
            var objs =
                Resources.FindObjectsOfTypeAll<GameObject>()
                    .Where(x => x != this && x.transform.parent == null && x.activeSelf)
                    .ToArray();
            foreach (var obj in objs) obj.SetActive(false);
            return objs;
        }

        private void ActivateAll(IEnumerable<GameObject> objs)
        {
            foreach (var obj in objs) obj.SetActive(true);
        }

        private Vector3 GetCentroid(Mesh mesh)
        {
            var triangles = mesh.triangles;
            var vertices = mesh.vertices;
            var centroid = Vector3.zero;
            var surface = 0.0F;

            for (var i = 0; i < triangles.Length; i += 3)
            {
                var v0 = vertices[triangles[i]];
                var v1 = vertices[triangles[i + 1]];
                var v2 = vertices[triangles[i + 2]];
                var s = Vector3.Cross(v1 - v0, v2 - v0).magnitude;
                centroid += (v0 + v1 + v2) * s;
                surface += s;
            }

            return centroid / (3.0F * surface);
        }

        private void InitCamera(Camera camera, Renderer renderer, Vector3 centroid)
        {
            camera.transform.position = renderer.transform.position + renderer.transform.rotation * Vector3.Scale(renderer.transform.lossyScale, centroid);
            camera.transform.rotation = renderer.transform.rotation;
        }

        private void InitBakerMaterial(Material material, Renderer renderer)
        {
            material.SetFloat("_BoundsScale", boundsScale);
        }

        private void InitCubemap(Cubemap cubemap)
        {
            cubemap.wrapMode = TextureWrapMode.Clamp;
            cubemap.filterMode = FilterMode.Bilinear;
            cubemap.anisoLevel = 0;
        }

        private void Render(Renderer renderer, Camera camera, Material bakerMaterial, Cubemap cubemap)
        {
            var oldMaterial = renderer.sharedMaterial;
            renderer.transform.rotation = Quaternion.identity;
            renderer.sharedMaterial = bakerMaterial;

            camera.RenderToCubemap(cubemap);

            renderer.sharedMaterial = oldMaterial;
        }

        private void SaveTexture(Cubemap cubemap, string filePath)
        {
            var tmp = new Texture2D(this.width, this.width * 6, GraphicsFormat.R8G8B8A8_UNorm, TextureCreationFlags.None);
            try
            {
                tmp.SetPixels(GetPixels(cubemap));
                var bytes = tmp.EncodeToPNG();
                File.WriteAllBytes(filePath, bytes);
                AssetDatabase.Refresh();
            }
            finally
            {
                DestroyImmediate(tmp);
            }
        }

        private Color[] GetPixels(Cubemap cubemap)
        {
            var pixels = new CubemapFace[]
                {
                    CubemapFace.PositiveX,
                    CubemapFace.NegativeX,
                    CubemapFace.PositiveY,
                    CubemapFace.NegativeY,
                    CubemapFace.PositiveZ,
                    CubemapFace.NegativeZ
                }
                .SelectMany(x => cubemap.GetPixels(x))
                .ToArray();

            return
                IterLines(pixels)
                    .Reverse()
                    .SelectMany(x => x)
                    .ToArray();
        }

        private IEnumerable<IEnumerable<Color>> IterLines(Color[] pixels)
        {
            foreach (var x in Enumerable.Range(0, width * 6).Select(x => x * width))
            {
                var arr = new Color[width];
                for (var i = 0; i < arr.Length; i++)
                {
                    arr[i] = pixels[x + i];
                }

                yield return arr;
            }
        }

        private void SaveImporter(string filePath)
        {
            var importer = (TextureImporter)AssetImporter.GetAtPath(filePath);

            var settings = new TextureImporterSettings()
            {
                textureType = TextureImporterType.Default,
                textureShape = TextureImporterShape.TextureCube,
                cubemapConvolution = TextureImporterCubemapConvolution.None,
                sRGBTexture = sRGBEnabled,
                alphaSource = TextureImporterAlphaSource.FromInput,
                alphaIsTransparency = false,
                npotScale = TextureImporterNPOTScale.ToNearest,
                readable = false,
                streamingMipmaps = false,
                mipmapEnabled = false,
                borderMipmap = false,
                mipmapFilter = TextureImporterMipFilter.BoxFilter,
                mipMapsPreserveCoverage = false,
                fadeOut = false,
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Point,
                aniso = 0
            };
            importer.SetTextureSettings(settings);

            var platformSettings = new TextureImporterPlatformSettings()
            {
                maxTextureSize = 2048,
                resizeAlgorithm = TextureResizeAlgorithm.Mitchell,
                // format = TextureImporterFormat.RGBA32
                format = textureFormat
            };
            importer.SetPlatformTextureSettings(platformSettings);

            importer.SaveAndReimport();
        }

#if SAVE_MATERIAL
        private void SaveMaterial(string materialPath, string cubemapPath, Vector3 centroid)
        {
            var material = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            if (material == null)
            {
                material = new Material(Shader.Find(CubemapBaker.jewelShaderName));
                AssetDatabase.CreateAsset(material, materialPath);
            }
            else
            {
                var tmp = new Material(Shader.Find(CubemapBaker.jewelShaderName));
                material.CopyPropertiesFromMaterial(tmp);
                DestroyImmediate(tmp);
            }
            var cubemap = AssetDatabase.LoadAssetAtPath<Texture>(cubemapPath);
            material.SetTexture("_NormalCube", cubemap);
            material.SetVector ("_Centroid"  , new Vector4(centroid.x, centroid.y, centroid.z, 1.0F));
        }
#endif
    }
#endif
}