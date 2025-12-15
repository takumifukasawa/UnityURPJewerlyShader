using Jewelry;
using UnityEngine;

namespace JewelryRenderer
{
    [RequireComponent(typeof(IJewelryView))]
    public class JewelryViewAutoUpdater : MonoBehaviour
    {
        private IJewelryView _jewelryView;

        void Awake()
        {
            _jewelryView = GetComponent<IJewelryView>();
        }
        
        void Start()
        {
            _jewelryView.ManualStart();
        }

        void Update()
        {
            _jewelryView.ManualUpdate();
        }
    }
}