using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class CEOEvil()
        : SwarmEvilPoolCard(1, CardType.Power, CardRarity.Rare, TargetType.Self, true)
    {
        protected override bool IsPlayable => base.Owner.Gold >= 100;
        protected override bool ShouldGlowGoldInternal => IsPlayable;

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
            HoverTipFactory.Static(StaticHoverTip.Block)];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            await PowerCmd.Apply<CEOEvilPower>(choiceContext, Owner.Creature, 1m, Owner.Creature, this, false);
        }

        protected override void OnUpgrade() => AddKeyword(CardKeyword.Innate);
    }
}
