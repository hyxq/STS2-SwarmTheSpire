using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using STS2RitsuLib.CardTags;
using STS2RitsuLib.Keywords;
using SwarmTheSpire;
using SwarmTheSpire.Powers;

namespace SwarmTheSpire.Cards
{
    public sealed class TheQueenOfHarpoons()
        : SwarmEvilPoolCard(2, CardType.Power, CardRarity.Rare, TargetType.Self, true)
    {
        protected override HashSet<CardTag> CanonicalTags => [SwarmCardTagIds.Evz.GetModCardTag()];

        public override IEnumerable<CardKeyword> CanonicalKeywords =>
        [
            SwarmKeywords.Harpoon.GetModKeywordCardKeyword(),
        ];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            await PowerCmd.Apply<QueenPower>(choiceContext, Owner.Creature, 1m, Owner.Creature, this);

            var handPile = PileType.Hand.GetPile(base.Owner);
            var harpoonCards = handPile.Cards
                .Where(c => c.HasModCardTag(SwarmCardTagIds.Harpoon.GetModCardTag()))
                .ToList();

            if (IsUpgraded)
            {
                foreach (var harpoonCard in harpoonCards)
                {
                    if (harpoonCard == this)
                        continue;

                    if (harpoonCard.IsUpgradable)
                        CardCmd.Upgrade(harpoonCard);
                }
            }

            foreach (var harpoonCard in harpoonCards)
            {
                if (CombatManager.Instance.IsOverOrEnding)
                    break;

                if (harpoonCard == this)
                    continue;

                var target = base.Owner.RunState.Rng.CombatTargets.NextItem(base.CombatState.HittableEnemies);
                await CardCmd.AutoPlay(choiceContext, harpoonCard, target);
            }
        }
    }
}
