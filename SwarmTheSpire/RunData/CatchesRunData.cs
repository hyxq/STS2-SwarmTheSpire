using MegaCrit.Sts2.Core.Saves.Runs;

namespace SwarmTheSpire.RunData
{
    /// <summary>
    ///     全局共享的捕获数据，放在 RunSavedData 中持久化。
    /// </summary>
    public sealed class CatchesRunState
    {
        /// <summary>本局累计捕获数。</summary>
        public int GlobalCatchesCount { get; set; }
    }
}
