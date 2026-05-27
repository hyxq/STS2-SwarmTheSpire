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
        : SwarmEvilPoolCard(2, CardType.Skill, CardRarity.Rare, TargetType.AllEnemies, true)
    {
        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Exhaust];

        public override bool GainsBlock => true;

        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
            [HoverTipFactory.FromPower<MilesPower>()];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
            [new PowerVar<MilesPower>(2m)];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            var combatState = CombatState;
            ArgumentNullException.ThrowIfNull(combatState);
            await PowerCmd.Apply<MilesPower>(choiceContext, combatState.HittableEnemies,
                DynamicVars["MilesPower"].BaseValue, Owner.Creature, this);

            var totalMiles = combatState.Enemies
                .Where(c => c.IsAlive)
                .Sum(c => c.GetPowerAmount<MilesPower>());

            if (totalMiles > 0)
            {
                var val = await DamageCmd.Attack(totalMiles).FromCard(this)
                    .TargetingAllOpponents(combatState)
                    .Execute(choiceContext);

                var actualDamage = val.Results.SelectMany(static r => r).Sum(static r => r.TotalDamage + r.OverkillDamage);

                // Gain gold equal to actual damage dealt
                await PlayerCmd.GainGold(actualDamage, Owner);
            }
        }

        protected override void OnUpgrade() => RemoveKeyword(CardKeyword.Exhaust);
    }
}
