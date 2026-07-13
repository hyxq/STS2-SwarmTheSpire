using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class EvilPlush() : SwarmEvilPoolCard(0, CardType.Skill, CardRarity.Rare, TargetType.AllEnemies, true)
    {
        private decimal _trackedGold;

        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Exhaust];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new PowerVar<MilesPower>(1m)];

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
            [HoverTipFactory.FromPower<MilesPower>()];

        public override async Task AfterCardPlayed(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            if (cardPlay.Card.Owner.Creature != Owner.Creature)
                return;

            var player = Owner.Creature.Player;
            if (player == null)
                return;

            var currentGold = (decimal)player.Gold;

            if (_trackedGold == 0)
            {
                _trackedGold = currentGold;
                return;
            }

            var delta = currentGold - _trackedGold;
            _trackedGold = currentGold;

            // When gaining gold, add this card to hand
            if (delta > 0)
            {
                await CardPileCmd.Add(this, PileType.Hand, CardPilePosition.Top);
            }
        }

        public override async Task AfterCardExhausted(PlayerChoiceContext choiceContext, CardModel card,
            bool causedByEthereal)
        {
            if (card != this)
                return;

            EnergyCost.AddThisCombat(+1);

            var combatState = CombatState;
            ArgumentNullException.ThrowIfNull(combatState);

            await PowerCmd.Apply<MilesPower>(choiceContext, combatState.HittableEnemies, DynamicVars["MilesPower"].BaseValue,
                Owner.Creature, this);
        }

        protected override void OnUpgrade()
        {
            DynamicVars["MilesPower"].UpgradeValueBy(1m);
        }
    }
}