using System;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace akanevrc.JewelShader.Editor
{
    [CustomEditor(typeof(CubemapBaker))]
    public class CubemapBakerEditor : UnityEditor.Editor
    {
        private static class I18n
        {
            public static string language = "en";

            private static string GetText(string enText, string jaText)
            {
                switch (I18n.language)
                {
                    case "en":
                        return enText;
                    case "ja":
                        return jaText;
                    default:
                        throw new NotSupportedException();
                }
            }

            public static string GetLanguageButtonLabel()
            {
                return GetText("日本語", "English");
            }

            public static string GetCubemapBakerTitle()
            {
                return GetText("Cubemap Baker", "キューブマップベイカー (Cubemap Baker)");
            }

            public static string GetCubemapBakerDescription()
            {
                return GetText
                (
                    "Use this GameObject to bake a Cubemap for akanevrc_JewelShader.",
                    "このGameObjectは、茜式宝石シェーダー用キューブマップをベイクするために使用します。"
                );
            }

            public static string GetHiddenConfigFoldout()
            {
                return GetText("Hidden configs", "非表示の設定");
            }

            public static string GetCameraPrefabLabel()
            {
                return GetText("Baker camera Prefab/GameObject", "ベイク用カメラのPrefab/GameObject");
            }

            public static string GetMeshPrefabLabel()
            {
                return GetText("Target mesh Prefab/GameObject", "処理対象のメッシュを含むPrefab/GameObject");
            }

            public static string GetManualCentroidLabel()
            {
                return GetText("Specify centroid manually", "中心座標を手動で指定");
            }

            public static string GetSRGBEnabledLabel()
            {
                return GetText("sRGB Enabled", "sRGB有効");
            }

            public static string GetCentroidLabel()
            {
                return GetText("Centroid position", "中心座標");
            }

            public static string GetWidthLabel()
            {
                return GetText("Baked cubemap width", "ベイクされるキューブマップのサイズ");
            }

            public static string GetBakeButtonLabel()
            {
                return GetText("Bake", "ベイク");
            }

            public static string GetSaveCubemapPanelTitle()
            {
                return GetText("Save cubemap texture", "キューブマップテクスチャの保存");
            }

            public static string GetSaveCubemapPanelMessage()
            {
                return GetText("Enter a name of new cubemap texture file.", "キューブマップテクスチャファイルの名前を入力");
            }

            public static string GetSaveMaterialPanelTitle()
            {
                return GetText("Save material", "マテリアルの保存");
            }

            public static string GetSaveMaterialPanelMessage()
            {
                return GetText("Enter a name of new material file.", "マテリアルファイルの名前を入力");
            }

            public static string GetNullMessageOfCameraPrefab()
            {
                return GetText("Enter camera Prefab/GameObject", "カメラPrefab/GameObjectを指定してください");
            }

            public static string GetNullMessageOfMeshPrefab()
            {
                return GetText("Enter mesh Prefab/GameObject", "メッシュを含むPrefab/GameObjectを指定してください");
            }

            public static string GetOutOfRangeMessageOfWidth()
            {
                return GetText("Width must be 1 or above", "サイズは1以上にしてください");
            }

            public static string GetBakeCanceledLog()
            {
                return GetText("Bake canceled", "ベイクがキャンセルされました");
            }

            public static string GetBakeSucceededLog()
            {
                return GetText("Bake succeeded", "ベイクが完了しました");
            }
        }

        private SerializedProperty cameraPrefab;
        private SerializedProperty meshPrefab;
        private SerializedProperty sRGBEnabled;
        private SerializedProperty manualCentroid;
        private SerializedProperty centroid;
        private SerializedProperty width;

        private string errorMessage = "";
        private bool errorIsCritical = false;

        private bool hiddenConfigFoldout = false;

        private void OnEnable()
        {
            this.cameraPrefab   = this.serializedObject.FindProperty(nameof(this.cameraPrefab));
            this.meshPrefab     = this.serializedObject.FindProperty(nameof(this.meshPrefab));
            this.manualCentroid = this.serializedObject.FindProperty(nameof(this.manualCentroid));
            this.sRGBEnabled    = this.serializedObject.FindProperty(nameof(this.sRGBEnabled));
            this.centroid       = this.serializedObject.FindProperty(nameof(this.centroid));
            this.width          = this.serializedObject.FindProperty(nameof(this.width));
        }

        public override void OnInspectorGUI()
        {
            var baker = (CubemapBaker)this.target;

            this.serializedObject.Update();

            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField(I18n.GetCubemapBakerTitle(), EditorStyles.boldLabel);
            if (GUILayout.Button(I18n.GetLanguageButtonLabel())) ToggleLanguage();
            EditorGUILayout.EndHorizontal();
            EditorGUILayout.Space();

            EditorGUILayout.HelpBox(I18n.GetCubemapBakerDescription(), MessageType.Info);
            EditorGUILayout.Space();

            EditorGUILayout.LabelField(I18n.GetMeshPrefabLabel());
            EditorGUILayout.PropertyField(this.meshPrefab, new GUIContent());
            EditorGUILayout.Space();

            EditorGUILayout.PropertyField(this.manualCentroid, new GUIContent(I18n.GetManualCentroidLabel()));
            EditorGUI.BeginDisabledGroup(!this.manualCentroid.boolValue);
            EditorGUILayout.LabelField(I18n.GetCentroidLabel());
            EditorGUILayout.PropertyField(this.centroid, new GUIContent());
            EditorGUI.EndDisabledGroup();
            EditorGUILayout.Space();

            EditorGUILayout.LabelField(I18n.GetSRGBEnabledLabel());
            EditorGUILayout.PropertyField(this.sRGBEnabled, new GUIContent());
            EditorGUILayout.Space();
            
            EditorGUILayout.LabelField(I18n.GetWidthLabel());
            EditorGUILayout.PropertyField(this.width, new GUIContent());
            EditorGUILayout.Space();

            this.hiddenConfigFoldout = EditorGUILayout.Foldout(this.hiddenConfigFoldout, I18n.GetHiddenConfigFoldout());
            if (this.hiddenConfigFoldout)
            {
                EditorGUI.indentLevel++;
                EditorGUILayout.LabelField(I18n.GetCameraPrefabLabel());
                EditorGUILayout.PropertyField(this.cameraPrefab, new GUIContent());
                EditorGUI.indentLevel--;
            }
            EditorGUILayout.Space();

            if (GUILayout.Button(I18n.GetBakeButtonLabel()))
            {
                if (Validate())
                {
                    var meshObj = (GameObject)this.meshPrefab.objectReferenceValue;

                    var cubemapPath = EditorUtility.SaveFilePanelInProject
                    (
                        I18n.GetSaveCubemapPanelTitle(),
                        $"BakedCubemap_{meshObj?.name}.png",
                        "png",
                        I18n.GetSaveCubemapPanelMessage()
                    );

                    if (string.IsNullOrEmpty(cubemapPath))
                    {
                        Debug.Log(I18n.GetBakeCanceledLog());
                    }
                    else
                    {
                        // material保存するときは使う
                        // var materialPath = EditorUtility.SaveFilePanelInProject
                        // (
                        //     I18n.GetSaveMaterialPanelTitle(),
                        //     $"JewelShader_Material_{meshObj?.name}.mat",
                        //     "mat",
                        //     I18n.GetSaveMaterialPanelMessage(),
                        //     Path.GetDirectoryName(cubemapPath)
                        // );

                        // if (string.IsNullOrEmpty(materialPath))
                        // {
                        //     Debug.Log(I18n.GetBakeCanceledLog());
                        // }
                        // else
                        // {
                        //     baker.Bake(cubemapPath, materialPath);
                        //     Debug.Log(I18n.GetBakeSucceededLog());
                        // }
                        
                        baker.Bake(cubemapPath);
                        Debug.Log(I18n.GetBakeSucceededLog());
                    }
                }
            }

            if (!string.IsNullOrEmpty(this.errorMessage))
            {
                EditorGUILayout.HelpBox(this.errorMessage, this.errorIsCritical ? MessageType.Error : MessageType.Warning);
            }

            this.serializedObject.ApplyModifiedProperties();
        }

        private void ToggleLanguage()
        {
            if (I18n.language == "en")
            {
                I18n.language = "ja";
            }
            else
            {
                I18n.language = "en";
            }
        }

        private bool Validate()
        {
            var cameraObj = this.cameraPrefab.objectReferenceValue;
            var meshObj   = this.meshPrefab  .objectReferenceValue;
            var widthVal  = this.width.intValue;

            if (cameraObj == null)
            {
                this.errorMessage = I18n.GetNullMessageOfCameraPrefab();
                return false;
            }
            else if (meshObj == null)
            {
                this.errorMessage = I18n.GetNullMessageOfMeshPrefab();
                return false;
            }
            else if (widthVal <= 0)
            {
                this.errorMessage = I18n.GetOutOfRangeMessageOfWidth();
                return false;
            }

            this.errorMessage = "";
            return true;
        }
    }
}
