using System.Linq;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Entities.Players;
using MegaCrit.Sts2.Core.Entities.Powers;
using MegaCrit.Sts2.Core.Factories;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Powers;
using MegaCrit.Sts2.Core.MonsterMoves.Intents;
using MegaCrit.Sts2.Core.ValueProps;
using STS2RitsuLib.Interop.AutoRegistration;
using SwarmTheSpire;
using SwarmTheSpire.Cards;
using SwarmTheSpire.Relics;
using STS2RitsuLib.Audio;
using MegaCrit.Sts2.Core.Localization;
using MegaCrit.Sts2.Core.Nodes.Vfx;

namespace SwarmTheSpire.Powers
{
    public sealed class FimSuffixPower : SwarmPowerTemplate
    {
        public override PowerType Type => PowerType.Buff;

        public override PowerStackType StackType => PowerStackType.Counter;

        public override bool AllowNegative => false;

        public override async Task AfterCardPlayed(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            if (Amount <= 0 || cardPlay.Card.Owner.Creature != Owner || cardPlay.Card.GetType().Name == "FimSuffix" || !cardPlay.IsFirstInSeries)
                return;

            await PowerCmd.Decrement(this);
            await TriggerSuffixEffects(choiceContext, cardPlay);
        }

        public override int ModifyCardPlayCount(CardModel card, Creature? target, int playCount)
        {
            if (card.Owner.Creature != Owner || card.GetType().Name == "FimSuffix" || card.Type != CardType.Power || Amount <= 0)
                return playCount;

            return playCount + 1;
        }

        public override Task AfterModifyingCardPlayCount(CardModel card)
        {
            Flash();
            TalkCmd.Play(
                new LocString("powers", "SWARM_THE_SPIRE_POWER_FIM_SUFFIX_POWER.power"),
                Owner,
                VfxColor.Red,
                VfxDuration.Short);
            return Task.CompletedTask;
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

                    case CardType.Status:
                    case CardType.Curse:
                        await TriggerStatusOrCurseEffect(choiceContext);
                        break;

                    case CardType.Power:
                        break;

                    default:
                        break;
                }
            }
            Sts2SfxAlignedFmod.PlayOneShot(Const.Sfx.FIMSuffix);
            await TriggerFallbackEffect(choiceContext, cardPlay);
        }

        private async Task TriggerAttackEffect(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            if (cardPlay.Target is null)
                return;

            await PowerCmd.Apply<VulnerablePower>(choiceContext, cardPlay.Target, 1m, Owner, cardPlay.Card, false);
            TalkCmd.Play(
                new LocString("powers", "SWARM_THE_SPIRE_POWER_FIM_SUFFIX_POWER.attack"),
                Owner,
                VfxColor.Red,
                VfxDuration.Short);
        }

        private async Task TriggerSkillEffect(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            var ownerPlayer = Owner.Player;
            if (ownerPlayer is null)
                return;

            var energyGain = 1m;
            await PlayerCmd.GainEnergy(energyGain, ownerPlayer);
            TalkCmd.Play(
                new LocString("powers", "SWARM_THE_SPIRE_POWER_FIM_SUFFIX_POWER.skill"),
                Owner,
                VfxColor.Red,
                VfxDuration.Short);
        }

        private async Task TriggerLocationEffect(PlayerChoiceContext choiceContext)
        {
            var ownerPlayer = Owner.Player;
            if (ownerPlayer is null)
                return;
            TalkCmd.Play(
                new LocString("powers", "SWARM_THE_SPIRE_POWER_FIM_SUFFIX_POWER.location"),
                Owner,
                VfxColor.Red,
                VfxDuration.Forever);
            await ExhaustPile(choiceContext, ownerPlayer, PileType.Hand);
            await PlayLocationSfx();
            await ExhaustPile(choiceContext, ownerPlayer, PileType.Draw);
            await PlayLocationSfx();
            await ExhaustPile(choiceContext, ownerPlayer, PileType.Discard);
            await PlayLocationSfx();

            var created = CardFactory.GetForCombat(ownerPlayer, [ModelDb.Card<Location>()], 20,
            ownerPlayer.RunState.Rng.CombatCardGeneration);
            await CardPileCmd.AddGeneratedCardsToCombat(created, PileType.Hand, ownerPlayer, CardPilePosition.Top);
            await PlayLocationSfx();
        }

        private static async Task PlayLocationSfx()
        {
            Sts2SfxAlignedFmod.PlayOneShot(Const.Sfx.Location2);
            Sts2SfxAlignedFmod.PlayOneShot(Const.Sfx.Location2);
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

        private async Task TriggerStatusOrCurseEffect(PlayerChoiceContext choiceContext)
        {
            var ownerPlayer = Owner.Player;
            if (ownerPlayer is null)
                return;
            TalkCmd.Play(
                new LocString("powers", "SWARM_THE_SPIRE_POWER_FIM_SUFFIX_POWER.clean"),
                Owner,
                VfxColor.Red,
                VfxDuration.Short);
            await ExhaustStatusAndCurseCards(choiceContext, ownerPlayer, PileType.Hand);
            await ExhaustStatusAndCurseCards(choiceContext, ownerPlayer, PileType.Draw);
            await ExhaustStatusAndCurseCards(choiceContext, ownerPlayer, PileType.Discard);
        }

        private static async Task ExhaustStatusAndCurseCards(PlayerChoiceContext choiceContext, Player player, PileType pileType)
        {
            var cards = pileType.GetPile(player).Cards
                .Where(card => card.Type == CardType.Status || card.Type == CardType.Curse)
                .ToList();

            foreach (var card in cards)
            {
                await CardCmd.Exhaust(choiceContext, card, false, false);
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

            var lowHpEnemy = cardPlay.Card.Type == CardType.Attack
                ? hittableEnemies.FirstOrDefault(e => e.CurrentHp < 5m)
                : null;

            if (lowHpEnemy is not null)
            {
                await CreatureCmd.Damage(choiceContext, lowHpEnemy, lowHpEnemy.CurrentHp, ValueProp.Unblockable, Owner, cardPlay.Card);
                var ownerPlayer = Owner.Player;
                if (ownerPlayer is not null)
                    MilesRelic.TryIncrementCatch(ownerPlayer);
                await Task.Delay(1000);
                TalkCmd.Play(
                new LocString("powers", "SWARM_THE_SPIRE_POWER_FIM_SUFFIX_POWER.catch"),
                Owner,
                VfxColor.Red,
                VfxDuration.Short);
                return;
            }

            var totalEnemyDamage = GetTotalEnemyIntentDamage(combatState);
            if (Owner.Block < totalEnemyDamage)
            {
                await CreatureCmd.GainBlock(Owner, 8m, ValueProp.Unpowered, null);
                await Task.Delay(1000);
                TalkCmd.Play(
                new LocString("powers", "SWARM_THE_SPIRE_POWER_FIM_SUFFIX_POWER.block"),
                Owner,
                VfxColor.Red,
                VfxDuration.Short);
                return;
            }

            if (hittableEnemies.Count() == 1)
            {
                await CreatureCmd.Damage(choiceContext, hittableEnemies.First(), 10m, ValueProp.Unblockable, Owner, cardPlay.Card);
                await Task.Delay(1000);
                TalkCmd.Play(
                new LocString("powers", "SWARM_THE_SPIRE_POWER_FIM_SUFFIX_POWER.single_strike"),
                Owner,
                VfxColor.Red,
                VfxDuration.Short);
                return;
            }

            foreach (var enemy in hittableEnemies)
            {
                await CreatureCmd.Damage(choiceContext, enemy, 7m, ValueProp.Unblockable, Owner, cardPlay.Card);
            }
            await Task.Delay(1000);
            TalkCmd.Play(
                new LocString("powers", "SWARM_THE_SPIRE_POWER_FIM_SUFFIX_POWER.multi_strike"),
                Owner,
                VfxColor.Red,
                VfxDuration.Short);
            return;
        }

        private decimal GetTotalEnemyIntentDamage(ICombatState combatState)
        {
            var totalIntentDamage = 0m;
            var playerCreatures = combatState.Allies;

            foreach (var enemy in combatState.HittableEnemies)
            {
                var monster = enemy.Monster;
                if (monster?.NextMove?.Intents == null)
                    continue;

                foreach (var intent in monster.NextMove.Intents)
                {
                    if (intent is AttackIntent attackIntent)
                    {
                        totalIntentDamage += attackIntent.GetTotalDamage(playerCreatures, enemy);
                    }
                }
            }

            return totalIntentDamage;
        }
    }
}
