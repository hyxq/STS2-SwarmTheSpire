using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Entities.Powers;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Powers;
using MegaCrit.Sts2.Core.ValueProps;

namespace SwarmTheSpire.Powers
{
    public sealed class CyberpunkHeartPower : SwarmPowerTemplate
    {
        public override PowerType Type => PowerType.Buff;

        public override PowerStackType StackType => PowerStackType.Single;

        public override string CustomPackedIconPath => Const.Paths.SharedPowerIcon;

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
            HoverTipFactory.FromPower<RegenPower>(),
        ];

        public override async Task AfterSideTurnEnd(PlayerChoiceContext choiceContext, CombatSide side, IEnumerable<Creature> participants)
	    {
		if (participants.Contains(base.Owner) && !base.Owner.IsDead)
		    {
			var artifactPower = base.Owner.GetPower<ArtifactPower>();
            if (artifactPower is null || artifactPower.Amount <= 0m)
                return;

            Flash();
            await CreatureCmd.Heal(base.Owner, artifactPower.Amount);
            await PowerCmd.Decrement(artifactPower);
		    }
	    }

    }
}

