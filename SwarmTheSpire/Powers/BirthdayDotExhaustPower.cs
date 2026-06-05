using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Entities.Powers;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Models.Powers;

namespace SwarmTheSpire.Powers
{
    public sealed class BirthdayDotExhaustPower : SwarmPowerTemplate
    {
        public override PowerType Type => PowerType.Debuff;

        public override PowerStackType StackType => PowerStackType.Counter;

        public override string CustomPackedIconPath => Const.Paths.SharedPowerIcon;

        public override async Task BeforeSideTurnStart(PlayerChoiceContext choiceContext, CombatSide side,
            IReadOnlyList<Creature> participants, ICombatState combatState)
        {
            if (side != Owner.Side)      
                return;

            Flash();

            await PowerCmd.Apply<FrailPower>(choiceContext, [Owner], 2m, Owner, null, false);
            await PowerCmd.Apply<VulnerablePower>(choiceContext, [Owner], 2m, Owner, null, false);
            await PowerCmd.Apply<WeakPower>(choiceContext, [Owner], 2m, Owner, null, false);
        }
    }
}
