using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Commands.Builders;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.ValueProps;
using STS2RitsuLib.CardTags;
using STS2RitsuLib.Keywords;
using SwarmTheSpire;
using SwarmTheSpire.Powers;
using SwarmTheSpire.Relics;

namespace SwarmTheSpire.Cards
{
    public sealed class HarpoonSnipe()
        : SwarmEvilPoolCard(2, CardType.Attack, CardRarity.Uncommon, TargetType.AnyEnemy, true)
    {
        public override IEnumerable<CardKeyword> CanonicalKeywords =>
        [
            SwarmKeywords.Harpoon.GetModKeywordCardKeyword(),
            SwarmKeywords.Catch.GetModKeywordCardKeyword(),
            CardKeyword.Retain,
        ];

        protected override HashSet<CardTag> CanonicalTags => [SwarmCardTagIds.Harpoon.GetModCardTag()];

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
            [HoverTipFactory.FromPower<ChargePower>()];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new DamageVar(20m, ValueProp.Move)];

        private bool HasQueenPower => CombatManager.Instance.IsInProgress && Owner.Creature.HasPower<QueenPower>();

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            ArgumentNullException.ThrowIfNull(cardPlay.Target);
            var shouldTriggerFatal = cardPlay.Target.Powers.All(static power => power.ShouldOwnerDeathTriggerFatal());
            var combatState = CombatState;

            var attack = await DamageCmd.Attack(DynamicVars.Damage.BaseValue).FromCard(this).Targeting(cardPlay.Target)
                .Execute(choiceContext);
            TryIncrementCatch(shouldTriggerFatal, attack);

            if (!HasQueenPower)
                return;

            ArgumentNullException.ThrowIfNull(combatState);
            var queenPowerCount = Owner.Creature.GetPowerAmount<QueenPower>();
            for (var i = 0; i < queenPowerCount; i++)
            {
                foreach (var hittableEnemy in combatState.HittableEnemies)
                {
                    var followUpAttack = await DamageCmd.Attack(DynamicVars.Damage.BaseValue).FromCard(this)
                        .Targeting(hittableEnemy)
                        .Execute(choiceContext);
                    TryIncrementCatch(shouldTriggerFatal, followUpAttack);
                }
            }

            return;

            void TryIncrementCatch(bool canTriggerFatal, AttackCommand attackCommand)
            {
                if (!canTriggerFatal ||
                    !attackCommand.Results.SelectMany(static r => r)
                        .Any(static result => result is { OverkillDamage: 0, WasTargetKilled: true }))
                    return;

                MilesRelic.TryIncrementCatch(Owner);
            }
        }

        protected override void OnUpgrade()
        {
            DynamicVars.Damage.UpgradeValueBy(5m);
        }
    }
}
