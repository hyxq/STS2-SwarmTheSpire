using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using STS2RitsuLib.Content;
using STS2RitsuLib.Interop.AutoRegistration;
using SwarmTheSpire;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class DualHarpoonEvil()
        : SwarmEvilPoolCard(2, CardType.Power, CardRarity.Uncommon, TargetType.Self, true)
    {
        public override IEnumerable<CardKeyword> CanonicalKeywords =>
            [CardKeyword.Retain];

        protected override IEnumerable<string> RegisteredCardTagIds => [SwarmCardTagIds.Evz];

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
            [HoverTipFactory.FromKeyword(CardKeyword.Retain)];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            await PowerCmd.Apply<DualHarpoonEvilPower>(choiceContext, Owner.Creature, 1m, Owner.Creature, this);
        }

        protected override void OnUpgrade()
        {
            EnergyCost.UpgradeBy(-1);
        }
    }
}
