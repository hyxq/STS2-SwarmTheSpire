using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Entities.Powers;
using MegaCrit.Sts2.Core.Factories;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Powers;
using MegaCrit.Sts2.Core.ValueProps;
using SwarmTheSpire.Cards;

namespace SwarmTheSpire.Powers
{
    public sealed class AutoShieldPower : SwarmPowerTemplate
    {
        public override PowerType Type => PowerType.Buff;

        public override PowerStackType StackType => PowerStackType.Counter;

        public override string CustomPackedIconPath => Const.Paths.SharedPowerIcon;

        public override decimal ModifyHpLostAfterOstyLate(Creature target, decimal amount, ValueProp props, Creature? dealer, CardModel? cardSource)
	    {
		if (target != base.Owner || !target.HasPower<ArtifactPower>())
            {
            return amount;
            }
		return 0m;
	    }

	    public override async Task AfterModifyingHpLostAfterOsty()
	    {
		var artifactPower = base.Owner.GetPower<ArtifactPower>();
		if (artifactPower != null)
		    {
		    await PowerCmd.Decrement(artifactPower);
		    }
	    }

        public override async Task AfterSideTurnEnd(PlayerChoiceContext choiceContext, CombatSide side, IEnumerable<Creature> participants)
        {
            if ((int)side == 2) await PowerCmd.TickDownDuration(this);
        }
    }
}

