using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using STS2RitsuLib.CardTags;
using SwarmTheSpire;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class FishyValor()
        : SwarmEvilPoolCard(1, CardType.Power, CardRarity.Uncommon, TargetType.Self, true)
    {
        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new PowerVar<FishyValorPower>(2m)];
        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
            [HoverTipFactory.FromPower<ChargePower>()];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            await PowerCmd.Apply<FishyValorPower>(choiceContext, Owner.Creature, DynamicVars["FishyValorPower"].BaseValue, Owner.Creature, this);
        }

        protected override void OnUpgrade()
	    {
            DynamicVars["FishyValorPower"].UpgradeValueBy(1m);
        }
    }
}