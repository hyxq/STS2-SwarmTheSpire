using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Factories;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Powers;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class FishyPreparations()
        : SwarmEvilPoolCard(1, CardType.Power, CardRarity.Uncommon, TargetType.Self, true)
    {
        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Retain];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new PowerVar<ChargePower>(1m)];

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
            HoverTipFactory.FromPower<ChargePower>(),
        ];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            await PowerCmd.Apply<FishyPreparationsPower>(choiceContext, Owner.Creature, 1m, Owner.Creature, this, false);
        }

        protected override void OnUpgrade() => AddKeyword(CardKeyword.Innate);
    }
}
