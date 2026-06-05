using MegaCrit.Sts2.Core.Modding;
using STS2RitsuLib;
using STS2RitsuLib.RunData;

namespace SwarmTheSpire.RunData
{
    /// <summary>
    ///     RunSavedData 注册入口。在 Mod 初始化时注册全局 / 玩家数据槽位。
    /// </summary>
    [ModInitializer(nameof(Init))]
    public static class CatchesRunDataEntry
    {
        /// <summary>全局捕获数据句柄。</summary>
        public static RunSavedData<CatchesRunState> Catches = null!;

        public static void Init()
        {
            using (RitsuLibFramework.BeginModDataRegistration(Const.ModId))
            {
                var store = RitsuLibFramework.GetRunSavedDataStore(Const.ModId);

                Catches = store.Register(
                    key: "catches",
                    defaultFactory: () => new CatchesRunState(),
                    options: new RunSavedDataOptions
                    {
                        WritePolicy = RunSavedDataWritePolicy.WhenNonDefault,
                    });
            }
        }
    }
}
