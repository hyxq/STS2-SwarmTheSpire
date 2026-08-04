using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Combat.History.Entries;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.CardPools;
using STS2RitsuLib.Interop.AutoRegistration;

namespace SwarmTheSpire.Cards;

[RegisterCard(typeof(StatusCardPool))]
public sealed class Filtered() : SwarmEvilPoolCard(-1, CardType.Status, CardRarity.Status, TargetType.None, true)

    {
    private const int MaxCardsPerTurn = 6;

    protected override bool ShouldGlowRedInternal => ShouldPreventCardPlay;

    private bool ShouldPreventCardPlay => CardsPlayedThisTurn >= MaxCardsPerTurn;

    public override int MaxUpgradeLevel => 0;

    public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Ethereal, CardKeyword.Unplayable];

    protected override IEnumerable<DynamicVar> CanonicalVars =>
    [
        new CalculationBaseVar(6m),
        new CalculationExtraVar(-1m),
        new CalculatedVar("CalculatedCards").WithMultiplier((card, _) =>
            Math.Min(MaxCardsPerTurn, ((Filtered)card).CardsPlayedThisTurn))
    ];

    private int CardsPlayedThisTurn => CombatManager.Instance.History.CardPlaysStarted.Count(e =>
        e.HappenedThisTurn(CombatState) && e.CardPlay.Card.Owner == Owner);


    public override bool ShouldPlay(CardModel card, AutoPlayType _)
    {
        if (card.Owner != Owner)
            return true;

        var pile = Pile;
        if (pile is null || pile.Type != PileType.Hand)
            return true;

        return !ShouldPreventCardPlay;
    }
}