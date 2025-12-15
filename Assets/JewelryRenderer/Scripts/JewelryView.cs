using System.Collections;
using System.Collections.Generic;
using JewelryRenderer;
using UnityEngine;

namespace Jewelry
{
    public class JewelryView<T> : MonoBehaviour, IJewelryView where T : Renderer
    {
        [SerializeField]
        protected T _renderer;

        protected List<Material> _cachedMaterials = new List<Material>();

        public virtual void ManualStart()
        {
            if (_renderer == null)
            {
                _renderer = GetComponentInChildren<T>();
            }
           
            if (_renderer == null)
            {
                Debug.LogError("Renderer not found.");
                return;
            }

            for (int i = 0; i < _renderer.sharedMaterials.Length; i++)
            {
                var cachedMaterial = new Material(_renderer.sharedMaterials[i]);
                cachedMaterial.name = $"{_renderer.sharedMaterials[i].name}_{i} Instance";
                _cachedMaterials.Add(cachedMaterial);
            }
            
            _renderer.materials = _cachedMaterials.ToArray();
        }

        public virtual void ManualUpdate()
        {
        }
    }
}