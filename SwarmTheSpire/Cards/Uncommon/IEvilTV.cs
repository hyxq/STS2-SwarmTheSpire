using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models.Powers;
using MegaCrit.Sts2.Core.ValueProps;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class IEvilTV() : SwarmEvilPoolCard(1, CardType.Skill, CardRarity.Uncommon, TargetType.Self, true)
    {
        protected override IEnumerable<DynamicVar> CanonicalVars =>
        [new PowerVar<MilesPower>(2m),
        new PowerVar<VulnerablePower>(1m),
        new PowerVar<ChargePower>(2m),
        new BlockVar(11m, ValueProp.Move)];

        public override bool GainsBlock => true;
        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
            HoverTipFactory.FromPower<VulnerablePower>(),
            HoverTipFactory.FromPower<MilesPower>(),
            HoverTipFactory.FromPower<ChargePower>(),
        ];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            var combatState = CombatState;
            ArgumentNullException.ThrowIfNull(combatState);
            var hittableEnemies = combatState.HittableEnemies;
            foreach (var item in hittableEnemies)
            await PowerCmd.Apply<MilesPower>(choiceContext, item, DynamicVars["MilesPower"].BaseValue,
            Owner.Creature, this);
            await PowerCmd.Apply<VulnerablePower>(choiceContext, Owner.Creature, DynamicVars["VulnerablePower"].BaseValue, Owner.Creature, this);
            await PowerCmd.Apply<ChargePower>(choiceContext, Owner.Creature, DynamicVars["ChargePower"].BaseValue, Owner.Creature, this);
            await CreatureCmd.GainBlock(Owner.Creature, DynamicVars.Block, cardPlay);
        }

        protected override void OnUpgrade()
        {
            DynamicVars.Block.UpgradeValueBy(2m);
            DynamicVars["MilesPower"].UpgradeValueBy(1m);
            DynamicVars["ChargePower"].UpgradeValueBy(1m);
        }
    }
}
