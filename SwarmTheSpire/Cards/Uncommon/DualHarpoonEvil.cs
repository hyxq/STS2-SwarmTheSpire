using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using STS2RitsuLib.CardTags;
using STS2RitsuLib.Interop.AutoRegistration;
using STS2RitsuLib.Keywords;
using SwarmTheSpire;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class DualHarpoonEvil()
        : SwarmEvilPoolCard(1, CardType.Power, CardRarity.Uncommon, TargetType.Self, true)
    {
        public override IEnumerable<CardKeyword> CanonicalKeywords =>
        [
            SwarmKeywords.Harpoon.GetModKeywordCardKeyword(),
        ];

        protected override HashSet<CardTag> CanonicalTags => [SwarmCardTagIds.Evz.GetModCardTag()];

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
            [HoverTipFactory.FromKeyword(CardKeyword.Exhaust)];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            await PowerCmd.Apply<DualHarpoonEvilPower>(choiceContext, Owner.Creature, 1m, Owner.Creature, this);
        }

            protected override void OnUpgrade() => AddKeyword(CardKeyword.Innate);
    }
}
