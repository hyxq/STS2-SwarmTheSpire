using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Nodes.Vfx;

namespace SwarmTheSpire.Cards
{
    public sealed class BuJinBuMan() : SwarmEvilPoolCard(0, CardType.Skill, CardRarity.Uncommon, TargetType.Self, true)
    {
        protected override IEnumerable<DynamicVar> CanonicalVars => new List<DynamicVar>
        {
            new EnergyVar(2),
        };

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
        base.EnergyHoverTip,
		HoverTipFactory.FromCard<Filtered>()
        ];

	    protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
	    {
		    await PlayerCmd.GainEnergy(base.DynamicVars.Energy.IntValue, base.Owner);
		    CardModel card = base.CombatState.CreateCard<Filtered>(base.Owner);
		    CardCmd.PreviewCardPileAdd(await CardPileCmd.AddGeneratedCardToCombat(card, PileType.Discard, base.Owner));
		    await Cmd.Wait(0.5f);
	    }

        protected override void OnUpgrade()
        {
            DynamicVars.Energy.UpgradeValueBy(1m);
        }
    }
}
