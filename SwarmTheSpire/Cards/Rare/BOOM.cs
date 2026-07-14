using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.ValueProps;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class Boom()
        : SwarmEvilPoolCard(2, CardType.Attack, CardRarity.Rare, TargetType.AllEnemies, true)
    {
        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Exhaust];

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
            [HoverTipFactory.FromPower<MilesPower>()];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new PowerVar<MilesPower>(1m)];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            var combatState = CombatState;
            ArgumentNullException.ThrowIfNull(combatState);

            // Give 1(2) MilesPower to all enemies
            var enemies = combatState.HittableEnemies.Where(c => c.IsAlive).ToList();
            foreach (var enemy in enemies)
            {
                await PowerCmd.Apply<MilesPower>(choiceContext, enemy,
                    DynamicVars["MilesPower"].BaseValue, Owner.Creature, this);
            }

            // Double the MilesPower stacks on all enemies
            foreach (var enemy in enemies)
            {
                var currentAmount = enemy.GetPowerAmount<MilesPower>();
                if (currentAmount > 0)
                {
                    await PowerCmd.Apply<MilesPower>(choiceContext, enemy,
                        currentAmount, Owner.Creature, this);
                }
            }

            // Deal damage equal to total MilesPower across all enemies
            var totalMiles = enemies.Sum(c => c.GetPowerAmount<MilesPower>());
            if (totalMiles > 0)
            {
                var val = await DamageCmd.Attack(totalMiles).FromCard(this)
                    .TargetingAllOpponents(combatState)
                    .Execute(choiceContext);

                var actualDamage = val.Results.SelectMany(static r => r)
                    .Sum(static r => r.TotalDamage + r.OverkillDamage);

                // Gain gold equal to actual damage dealt
                await PlayerCmd.GainGold(actualDamage, Owner);
            }
        }

        protected override void OnUpgrade()
        {
            DynamicVars["MilesPower"].UpgradeValueBy(1m);
        }
    }
}
