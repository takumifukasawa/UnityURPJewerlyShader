using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace Jewelry
{
    public class SkinnedJewelryView : JewelryView<SkinnedMeshRenderer>
    {
        private const string BONE_MATRICES_PROP = "_BoneMatrices";
        private const string INV_BONE_MATRICES_PROP = "_InverseBoneMatrices";

        private Matrix4x4[] _boneMatrices; // mesh.bindposes (Inverse Bind Pose)
        private Matrix4x4[] _inverseBoneMatrices; // mesh.bindposes (Inverse Bind Pose)

        public override void ManualStart()
        {
            base.ManualStart();

            InitManualSkinning();
        }

        public override void ManualUpdate()
        {
            UpdateInverseBoneSkinning();
        }

        void InitManualSkinning()
        {
            var boneCount = _renderer.bones.Length;
            _boneMatrices = new Matrix4x4[boneCount];
            _inverseBoneMatrices = new Matrix4x4[boneCount];
        }

        void UpdateInverseBoneSkinning()
        {
            // 現在のワールド逆行列を計算
            for (int i = 0; i < _renderer.bones.Length; i++)
            {
                var bone = _renderer.bones[i];
                var bindPose = _renderer.sharedMesh.bindposes[i];
                _boneMatrices[i] = bone.localToWorldMatrix * bindPose;
                _inverseBoneMatrices[i] = _boneMatrices[i].inverse;
            }

            for (int i = 0; i < _cachedMaterials.Count; i++)
            {
                var cachedMaterial = _cachedMaterials[i];
                // マテリアルに行列配列を設定
                cachedMaterial.SetMatrixArray(BONE_MATRICES_PROP, _boneMatrices);
                cachedMaterial.SetMatrixArray(INV_BONE_MATRICES_PROP, _inverseBoneMatrices);
            }
        }
    }
}