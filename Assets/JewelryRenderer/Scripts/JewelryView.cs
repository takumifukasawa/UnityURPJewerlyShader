using System.Collections;
using System.Collections.Generic;
using JewelryRenderer;
using UnityEngine;

namespace Jewelry
{
    public class JewelryView : MonoBehaviour
    {
        [SerializeField]
        private MeshRenderer _renderer;

        private Material _cachedMaterial;

        void Start()
        {
            _cachedMaterial = new Material(_renderer.sharedMaterial);
            _renderer.material = _cachedMaterial;
        }
    }
}