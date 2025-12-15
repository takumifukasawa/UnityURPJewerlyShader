using System;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using Random = UnityEngine.Random;

namespace JewelryEX
{
    public class RadialCausticsDecalProjector : MonoBehaviour
    {
        // [SerializeField]
        private DecalProjector _decalProjector;

        [SerializeField]
        private Material _decalMaterial;

        [SerializeField]
        private float _scaleAdjustment = 1.0f;

        private Material _cachedMaterial;

        public void ManualStart()
        {
            var _decalProjector = GetComponent<DecalProjector>();
            _cachedMaterial = new Material(_decalMaterial);
            _decalProjector.material = _cachedMaterial;
            _cachedMaterial.SetVector("_RadialOffset1", Random.onUnitSphere * 100);
            _cachedMaterial.SetVector("_RadialOffset2", Random.onUnitSphere * 100);
        }

        public void SetColors(Color baseColor, Color emissionColor)
        {
            if (_cachedMaterial != null)
            {
                _cachedMaterial.SetColor("_BaseColor", baseColor);
                _cachedMaterial.SetColor("_EmissionColor", emissionColor);
            }
        }

        public void SetBaseColor()
        {
            if (_cachedMaterial != null)
            {
                _cachedMaterial.SetColor("_BaseColor", Color.white);
            }
        }
        
        public void SetEmissionColor()
        {
            if (_cachedMaterial != null)
            {
                _cachedMaterial.SetColor("_EmissionColor", Color.black);
            }
        }
    }
}