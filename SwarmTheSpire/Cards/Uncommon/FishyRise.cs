using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Runs;
using MegaCrit.Sts2.Core.Saves.Runs;
using MegaCrit.Sts2.Core.ValueProps;
using SwarmTheSpire.RunData;

namespace SwarmTheSpire.Cards
{
public sealed class FishyRise()
    : SwarmEvilPoolCard(2, CardType.Attack, CardRarity.Uncommon, TargetType.AnyEnemy, true)
{
    protected override IEnumerable<DynamicVar> CanonicalVars => new DynamicVar[]
    {   new DamageVar(1m, ValueProp.Move),
		new CalculationBaseVar(0m)};

    protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
	{
		int hits = Owner?.RunState is RunState runState
            ? CatchesRunDataEntry.Catches.Get(runState).GlobalCatchesCount
            : 0;
		ArgumentNullException.ThrowIfNull(cardPlay.Target, "cardPlay.Target");
		await DamageCmd.Attack(base.DynamicVars.Damage.BaseValue)
			.WithHitCount(hits)
			.FromCard(this)
			.Targeting(cardPlay.Target)
			.WithHitFx("vfx/vfx_attack_slash")
			.Execute(choiceContext);
	}
    protected override void OnUpgrade()
	{
		base.EnergyCost.UpgradeBy(-1);
	}
}
}
