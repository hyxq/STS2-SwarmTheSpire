using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Entities.Players;
using MegaCrit.Sts2.Core.Entities.Powers;
using MegaCrit.Sts2.Core.Factories;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Powers;
using MegaCrit.Sts2.Core.ValueProps;
using STS2RitsuLib.Interop.AutoRegistration;
using SwarmTheSpire;
using SwarmTheSpire.Cards;
using SwarmTheSpire.Relics;

namespace SwarmTheSpire.Powers
{
    public sealed class FimSuffixPower : SwarmPowerTemplate
    {
        public override PowerType Type => PowerType.Buff;

        public override PowerStackType StackType => PowerStackType.Counter;

        public override bool AllowNegative => false;

        public override async Task AfterCardPlayed(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            if (Amount <= 0 || cardPlay.Card.Owner.Creature != Owner || cardPlay.Card.GetType().Name == "FimSuffix")
                return;

            await PowerCmd.Decrement(this);
            await TriggerSuffixEffects(choiceContext, cardPlay);
        }

        private async Task TriggerSuffixEffects(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            if (cardPlay.Card is Location)
            {
                await TriggerLocationEffect(choiceContext);
            }
            else
            {
                switch (cardPlay.Card.Type)
                {
                    case CardType.Attack:
                        await TriggerAttackEffect(choiceContext, cardPlay);
                        break;

                    case CardType.Skill:
                        await TriggerSkillEffect(choiceContext, cardPlay);
                        break;

                    case CardType.Power:
                        await TriggerPowerEffect(choiceContext, cardPlay);
                        break;

                    default:
                        break;
                }
            }

            await TriggerFallbackEffect(choiceContext, cardPlay);
        }

        private async Task TriggerAttackEffect(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            if (cardPlay.Target is null)
                return;

            await PowerCmd.Apply<VulnerablePower>(choiceContext, cardPlay.Target, 1m, Owner, cardPlay.Card, false);
        }

        private async Task TriggerSkillEffect(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            var ownerPlayer = Owner.Player;
            if (ownerPlayer is null)
                return;

            var energyGain = 1m;
            await PlayerCmd.GainEnergy(energyGain, ownerPlayer);
        }

        private async Task TriggerLocationEffect(PlayerChoiceContext choiceContext)
        {
            var ownerPlayer = Owner.Player;
            if (ownerPlayer is null)
                return;

            await ExhaustPile(choiceContext, ownerPlayer, PileType.Hand);
            await ExhaustPile(choiceContext, ownerPlayer, PileType.Draw);
            await ExhaustPile(choiceContext, ownerPlayer, PileType.Discard);


            var created = CardFactory.GetForCombat(ownerPlayer, [ModelDb.Card<Location>()], 21,
            ownerPlayer.RunState.Rng.CombatCardGeneration);
        await CardPileCmd.AddGeneratedCardsToCombat(created, PileType.Hand, ownerPlayer, CardPilePosition.Top);
        }

        private async Task TriggerPowerEffect(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            // Power cards should replay the original power card once.
            await CardCmd.AutoPlay(choiceContext, cardPlay.Card, cardPlay.Target, AutoPlayType.Default, true, false);
        }

        private async Task TriggerTypeSpecificEffect(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            switch (cardPlay.Card.Type)
            {
                case CardType.Attack:
                    await TriggerAttackEffect(choiceContext, cardPlay);
                    break;

                case CardType.Skill:
                    await TriggerSkillEffect(choiceContext, cardPlay);
                    break;

                default:
                    break;
            }
        }

        private static async Task ExhaustPile(PlayerChoiceContext choiceContext, Player player, PileType pileType)
        {
            var cards = pileType.GetPile(player).Cards.ToList();
            foreach (var card in cards)
            {
                await CardCmd.Exhaust(choiceContext, card, false, false);
            }
        }

        private bool AnyEnemyIntendsToAttack()
        {
            var combatState = CombatState;
            if (combatState is null)
                return false;

            return combatState.HittableEnemies.Any(e => e.Monster?.IntendsToAttack == true);
        }

        private async Task TriggerFallbackEffect(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            Flash();

            var combatState = CombatState;
            if (combatState is null)
                return;

            var hittableEnemies = combatState.HittableEnemies;
            if (!hittableEnemies.Any())
                return;

            if (Owner.Block >= 30m)
            {
                // Skip block gain and proceed to damage logic
            }
            else if (hittableEnemies.Any(e => e.Monster?.IntendsToAttack == true))
            {
                await CreatureCmd.GainBlock(Owner, 8m, ValueProp.Unpowered, null);
                return;
            }

            var lowHpEnemy = cardPlay.Card.Type == CardType.Attack
                ? hittableEnemies.FirstOrDefault(e => e.CurrentHp < 5m)
                : null;

            if (lowHpEnemy is not null)
            {
                await CreatureCmd.Damage(choiceContext, lowHpEnemy, lowHpEnemy.CurrentHp, ValueProp.Unblockable, Owner, cardPlay.Card);
                var ownerPlayer = Owner.Player;
                if (ownerPlayer is not null)
                    MilesRelic.TryIncrementCatch(ownerPlayer);
                return;
            }

            if (hittableEnemies.Count() == 1)
            {
                await CreatureCmd.Damage(choiceContext, hittableEnemies.First(), 10m, ValueProp.Unblockable, Owner, cardPlay.Card);
                return;
            }

            foreach (var enemy in hittableEnemies)
            {
                await CreatureCmd.Damage(choiceContext, enemy, 7m, ValueProp.Unblockable, Owner, cardPlay.Card);
            }
        }
    }
}
