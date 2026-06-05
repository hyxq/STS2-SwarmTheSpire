using System.ComponentModel;
using MegaCrit.Sts2.Core.Saves.Runs;

namespace SwarmTheSpire.Data
{
    public sealed class CatchesData : INotifyPropertyChanged
    {
        public static readonly CatchesData Instance = new();

        private int _globalCatchesCount;
        private int _currentCombatCatches;

        [SavedProperty]
        public int GlobalCatchesCount
        {
            get => _globalCatchesCount;
            set
            {
                if (_globalCatchesCount == value)
                    return;

                _globalCatchesCount = value;
                OnPropertyChanged(nameof(GlobalCatchesCount));
            }
        }

        public int CurrentCombatCatches
        {
            get => _currentCombatCatches;
            set
            {
                if (_currentCombatCatches == value)
                    return;

                _currentCombatCatches = value;
                OnPropertyChanged(nameof(CurrentCombatCatches));
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        private void OnPropertyChanged(string propertyName) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
