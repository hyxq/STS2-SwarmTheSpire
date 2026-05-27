using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using STS2RitsuLib.CardTags;
using STS2RitsuLib.Keywords;
using SwarmTheSpire;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class TheQueenOfHarpoons()
        : SwarmEvilPoolCard(2, CardType.Power, CardRarity.Rare, TargetType.Self, true)
    {
        protected override HashSet<CardTag> CanonicalTags => [SwarmCardTagIds.Evz.GetModCardTag()];

        public override IEnumerable<CardKeyword> CanonicalKeywords =>
        [
            SwarmKeywords.Harpoon.GetModKeywordCardKeyword(),
        ];
        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            await PowerCmd.Apply<QueenPower>(choiceContext, Owner.Creature, 1m, Owner.Creature, this);
        }

        protected override void OnUpgrade()
        {
            EnergyCost.UpgradeBy(-1);
        }
    }
}
