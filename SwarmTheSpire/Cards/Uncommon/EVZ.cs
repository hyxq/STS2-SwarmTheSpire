using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Factories;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Saves.Runs;
using STS2RitsuLib.CardTags;
using STS2RitsuLib.Interop.AutoRegistration;
using SwarmTheSpire;

namespace SwarmTheSpire.Cards
{
    [RegisterOwnedCardTag("evz")]
    public sealed class EVZ()
        : SwarmEvilPoolCard(0, CardType.Skill, CardRarity.Uncommon, TargetType.Self, true)
    {
        private const int MaxChoiceCount = 3;
        private const int MaxEnergyReduction = 3;
        private const int MaxPlayCount = 3;

        private CardModel? _mockSelectedCard;

        public override int MaxUpgradeLevel => 9;

        [SavedProperty]
        public int ChoiceCount { get; set; } = 1;

        [SavedProperty]
        public int PlayCount { get; set; } = 1;

        [SavedProperty]
        public int EnergyReduction { get; set; }

        protected override IEnumerable<DynamicVar> CanonicalVars =>
        [
            new DynamicVar("ChoiceCount", ChoiceCount),
            new DynamicVar("PlayCount", PlayCount),
            new DynamicVar("EnergyReduction", EnergyReduction),
        ];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            var playCount = PlayCount;
            var choiceCount = ChoiceCount;

            for (var p = 0; p < playCount; p++)
            {
                CardModel? pick;
                if (_mockSelectedCard is null)
                {
                    var pool = Owner.Character.CardPool
                        .GetUnlockedCards(Owner.UnlockState, Owner.RunState.CardMultiplayerConstraint)
                        .Where(static c => c.HasModCardTag(SwarmCardTagIds.Evz))
                        .ToList();

                    var choices = CardFactory.GetDistinctForCombat(Owner, pool, choiceCount,
                            Owner.RunState.Rng.CombatCardGeneration)
                        .ToList();

                    pick = await CardSelectCmd.FromChooseACardScreen(choiceContext, choices, Owner, true);
                }
                else
                {
                    pick = _mockSelectedCard;
                }

                if (pick is null)
                    continue;

                if (EnergyReduction > 0)
                    pick.EnergyCost.AddThisCombat(-EnergyReduction);

                await CardPileCmd.AddGeneratedCardToCombat(pick, PileType.Hand, Owner, CardPilePosition.Top);
            }
        }

        protected override void OnUpgrade()
        {
            AssertMutable();

            var candidates = new List<Action>();
            if (ChoiceCount < MaxChoiceCount)
                candidates.Add(() => { ChoiceCount++; DynamicVars["ChoiceCount"].UpgradeValueBy(1m); });
            if (PlayCount < MaxPlayCount)
                candidates.Add(() => { PlayCount++; DynamicVars["PlayCount"].UpgradeValueBy(1m); });
            if (EnergyReduction < MaxEnergyReduction)
                candidates.Add(() => { EnergyReduction++; DynamicVars["EnergyReduction"].UpgradeValueBy(1m); });

            if (candidates.Count > 0)
                candidates[Random.Shared.Next(candidates.Count)]();
        }

        public void MockSelectedCard(CardModel card)
        {
            AssertMutable();
            _mockSelectedCard = card;
        }
    }
}
