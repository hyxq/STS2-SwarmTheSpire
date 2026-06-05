using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Combat.History.Entries;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Factories;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.ValueProps;

namespace SwarmTheSpire.Cards
{
    public sealed class AddToCart()
        : SwarmEvilPoolCard(1, CardType.Skill, CardRarity.Uncommon, TargetType.Self, true)
    {
        private decimal GetGoldCost() =>
            ((CalculatedVar)DynamicVars.CalculatedDamage).Calculate(null);

        protected override bool IsPlayable => base.Owner.Gold >= GetGoldCost();
        protected override bool ShouldGlowGoldInternal => IsPlayable;

        protected override IEnumerable<DynamicVar> CanonicalVars =>
        [
            new DamageVar(10m, ValueProp.Unpowered),
            new CalculationBaseVar(10m),
            new ExtraDamageVar(10m),
            new CalculatedDamageVar(ValueProp.Unpowered).WithMultiplier((card, _) =>
                CombatManager.Instance.History.CardPlaysFinished
                    .Count(e => e.HappenedThisTurn(card.CombatState)
                        && e.CardPlay.Card.Owner == card.Owner
                        && e.CardPlay.Card is AddToCart)),
        ];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            var goldCost = GetGoldCost();
            await PlayerCmd.GainGold(-goldCost, Owner);

            var pools = Owner.UnlockState.CharacterCardPools.ToList();
            if (pools.Count > 1)
                pools.Remove(Owner.Character.CardPool);

            var cards = pools.SelectMany(c =>
                    c.GetUnlockedCards(Owner.UnlockState, Owner.RunState.CardMultiplayerConstraint))
                .ToList();

            var choices = CardFactory.GetDistinctForCombat(Owner, cards, 3,
                    Owner.RunState.Rng.CombatCardGeneration)
                .ToList();

            var pick = await CardSelectCmd.FromChooseACardScreen(choiceContext, choices, Owner, true);
            if (pick != null)
            {
                pick.SetToFreeThisTurn();
                await CardPileCmd.AddGeneratedCardToCombat(pick, PileType.Hand, Owner, CardPilePosition.Top);
            }
        }

        protected override PileType GetResultPileTypeForCardPlay()
        {
            var result = base.GetResultPileTypeForCardPlay();
            return result != PileType.Discard ? result : PileType.Hand;
        }

        protected override void OnUpgrade() => EnergyCost.UpgradeBy(-1);
    }
}
