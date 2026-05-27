using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.CardPools;
using MegaCrit.Sts2.Core.Models.Powers;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class BirthdayExclaim()
        : SwarmTokenPoolCard(2, CardType.Skill, CardRarity.Token, TargetType.Self, true)
    {
        public override bool CanBeGeneratedInCombat => false;

        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Exhaust, CardKeyword.Ethereal];

        protected override IEnumerable<DynamicVar> CanonicalVars =>
        [
            new DynamicVar("Draw", 3m),
            new DynamicVar("Energy", 3m),
        ];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            // Remove all debuffs from the owner
            foreach (var power in Owner.Creature.Powers.ToList())
            {
                if (power is WeakPower or VulnerablePower or FrailPower or BirthdayDotExhaustPower
                    or DexterityPower { Amount: < 0 } or StrengthPower { Amount: < 0 })
                {
                    await PowerCmd.Remove(power);
                }
            }

            await CardPileCmd.Draw(choiceContext, DynamicVars["Draw"].BaseValue, Owner, false);
            await PlayerCmd.GainEnergy(DynamicVars["Energy"].BaseValue, Owner);
            await PowerCmd.Apply<AdventTrackingPower>(choiceContext, Owner.Creature, 12m, Owner.Creature, this, false);
        }

        protected override void OnUpgrade() => RemoveKeyword(CardKeyword.Ethereal);
    }
}
