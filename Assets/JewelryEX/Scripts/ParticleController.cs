using System;
using System.Collections.Generic;
using UnityEngine;

namespace JewelryEX
{
    public class ParticleController : MonoBehaviour
    {
        // ---------------------------------------------------------------------
        // members, properties
        // ---------------------------------------------------------------------

        // serialize ------------------------------------------------

        [SerializeField]
        private bool _autoOffsetToCameraEnabled = false;

        [SerializeField]
        [Range(0, 1)]
        private float _offsetToCameraRate = 0.1f;

        [Space(13)]
        [Header("For Luna")]
        [SerializeField]
        private List<ParticleSystem> _particleSystems;

        // public ------------------------------------------------

        public ParticleSystem ParticleSystem => _particleSystem;

        public bool IsPlaying => _particleSystem != null && _particleSystem.isPlaying;

        public bool IsValid => _particleSystem != null;

        public Action OnUpdatePlaying;

        // private ------------------------------------------------

        private ParticleSystem _particleSystem;
        private Transform _chaseTargetOffsetToCameraRate;

        private Material _material;
        private ParticleSystemRenderer _particleSystemRenderer;

        private Transform _chaseTargetTransform;

        // ---------------------------------------------------------------------
        // methods
        // ---------------------------------------------------------------------

        // engine ------------------------------------------------

        public virtual void ManualStart()
        {
            _particleSystem = GetComponent<ParticleSystem>();
        }

        public void ManualUpdate()
        {
            if (_chaseTargetTransform != null)
            {
                transform.position = _chaseTargetTransform.position;
            }

            if (IsPlaying)
            {
                OnUpdatePlaying?.Invoke();
            }
        }

        // public ------------------------------------------------

        public virtual void Play()
        {
#if UNITY_LUNA
            for (int i = 0; i < _particleSystems.Count; i++)
            {
                _particleSystems[i].Simulate(0, true);
                _particleSystems[i].Play();
            }
#else
            _particleSystem.Simulate(0, true);
            _particleSystem.Play();
#endif
        }

        public virtual void Play(Vector3 position)
        {
            this.transform.position = GetEmitPosition(position);
            Play();
        }

        public void SetAutoDestroyOnStop()
        {
            var main = _particleSystem.main;
#if !UNITY_LUNA
            main.stopAction = ParticleSystemStopAction.Destroy;
#endif
        }

        public void SetChaseTargetTransform(Transform chaseTargetTransform)
        {
            _chaseTargetTransform = chaseTargetTransform;
        }

#if !UNITY_LUNA
        public virtual void Emit(ParticleSystem.EmitParams emitParams, int emitCount)
        {
            _particleSystem.Emit(emitParams, emitCount);
        }

#endif // !UNITY_LUNA

        public virtual void Stop()
        {
            _particleSystem.Stop();
        }

        public virtual void SetStartColor(Color color)
        {
            var ms = _particleSystem.main;
            ms.startColor = color;
        }

        public void SetPosition(Vector3 p)
        {
            transform.position = p;
        }

        public void OffsetPosition(Vector3 p)
        {
            transform.position += p;
        }

        public void OffsetLocalPosition(Vector3 p)
        {
            transform.localPosition += p;
        }

        public void OffsetToCameraRate(float rate, Camera camera = null)
        {
            camera = camera == null ? Camera.main : camera;
            transform.position = Vector3.Lerp(
                this.transform.position,
                camera.transform.position,
                rate
            );
        }

        public void SetScale(float scale)
        {
            this.transform.localScale = new Vector3(scale, scale, scale);
        }

        public void SetFloat(string name, float f)
        {
            CacheMaterial();
            _material.SetFloat(name, f);
        }

        public void SetVector(string name, Vector2 v)
        {
            CacheMaterial();
            _material.SetVector(name, v);
        }

        public void SetTexture(string name, Texture2D texture)
        {
            CacheMaterial();
            _material.SetTexture(name, texture);
        }

        // private ------------------------------------------------

        void CacheMaterial()
        {
            if (_material == null)
            {
                _particleSystemRenderer = _particleSystem.GetComponent<ParticleSystemRenderer>();
                _material = new Material(_particleSystemRenderer.sharedMaterial);
                _particleSystemRenderer.material = _material;
            }
        }

        Vector3 GetEmitPosition(Vector3 position)
        {
            // fallback
            if (Camera.main == null)
            {
                return position;
            }

            return _autoOffsetToCameraEnabled
                       ? Vector3.Lerp(
                           position,
                           Camera.main.transform.position,
                           _offsetToCameraRate
                       )
                       : position;
        }
    }
}