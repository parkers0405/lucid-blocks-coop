using System;
using System.Buffers;
using System.Buffers.Binary;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security;
using System.Security.Permissions;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Actors.Enemies;
using Assets.Scripts.Actors;
using Assets.Scripts.Actors.Enemies;
using Assets.Scripts.Actors.Player;
using Assets.Scripts.Camera;
using Assets.Scripts.Game.Combat;
using Assets.Scripts.Game.Combat.EnemyDebuffs;
using Assets.Scripts.Game.Combat.EnemySpecialAttacks;
using Assets.Scripts.Game.MapGeneration;
using Assets.Scripts.Game.Other;
using Assets.Scripts.Game.Spawning;
using Assets.Scripts.Game.Spawning.New;
using Assets.Scripts.Game.Spawning.New.Timelines;
using Assets.Scripts.Inventory.Stats;
using Assets.Scripts.Inventory__Items__Pickups;
using Assets.Scripts.Inventory__Items__Pickups.Chests;
using Assets.Scripts.Inventory__Items__Pickups.Interactables;
using Assets.Scripts.Inventory__Items__Pickups.Items;
using Assets.Scripts.Inventory__Items__Pickups.Pickups;
using Assets.Scripts.Inventory__Items__Pickups.Weapons;
using Assets.Scripts.Inventory__Items__Pickups.Weapons.Attacks;
using Assets.Scripts.Inventory__Items__Pickups.Weapons.Projectiles;
using Assets.Scripts.Managers;
using Assets.Scripts.MapGeneration.ProceduralTiles;
using Assets.Scripts.Menu.Shop;
using Assets.Scripts.Movement;
using Assets.Scripts.Objects.Pooling;
using Assets.Scripts.UI;
using Assets.Scripts.UI.InGame.Levelup;
using Assets.Scripts.UI.InGame.Rewards;
using Assets.Scripts.Utility;
using Assets.Scripts._Data;
using Assets.Scripts._Data.MapsAndStages;
using BepInEx;
using BepInEx.Configuration;
using BepInEx.Core.Logging.Interpolation;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using BepInEx.Unity.IL2CPP.Utils.Collections;
using HarmonyLib;
using Il2CppInterop.Runtime.Attributes;
using Il2CppInterop.Runtime.Injection;
using Il2CppInterop.Runtime.InteropTypes;
using Il2CppInterop.Runtime.InteropTypes.Arrays;
using Il2CppSystem;
using Il2CppSystem.Collections.Generic;
using Il2CppSystem.IO;
using Megabonk.BonkWithFriends.Components;
using Megabonk.BonkWithFriends.Debug.UI;
using Megabonk.BonkWithFriends.HarmonyPatches.Combat;
using Megabonk.BonkWithFriends.HarmonyPatches.Enemies;
using Megabonk.BonkWithFriends.HarmonyPatches.Enemies.SpecialAttacks;
using Megabonk.BonkWithFriends.HarmonyPatches.Game;
using Megabonk.BonkWithFriends.HarmonyPatches.Items;
using Megabonk.BonkWithFriends.HarmonyPatches.Player;
using Megabonk.BonkWithFriends.IO;
using Megabonk.BonkWithFriends.Localization;
using Megabonk.BonkWithFriends.Localization.Tables;
using Megabonk.BonkWithFriends.Managers;
using Megabonk.BonkWithFriends.Managers.Enemies;
using Megabonk.BonkWithFriends.Managers.Items;
using Megabonk.BonkWithFriends.Managers.Player;
using Megabonk.BonkWithFriends.Managers.Revive;
using Megabonk.BonkWithFriends.Managers.Server;
using Megabonk.BonkWithFriends.Managers.World;
using Megabonk.BonkWithFriends.MonoBehaviours.Camera;
using Megabonk.BonkWithFriends.MonoBehaviours.Enemies;
using Megabonk.BonkWithFriends.MonoBehaviours.Player;
using Megabonk.BonkWithFriends.Net;
using Megabonk.BonkWithFriends.Networking.Handlers;
using Megabonk.BonkWithFriends.Networking.Messages;
using Megabonk.BonkWithFriends.Networking.Messages.Client;
using Megabonk.BonkWithFriends.Networking.Messages.Server;
using Megabonk.BonkWithFriends.Networking.Messages.Shared;
using Megabonk.BonkWithFriends.Networking.Models;
using Megabonk.BonkWithFriends.Networking.Steam;
using Megabonk.BonkWithFriends.Player;
using Megabonk.BonkWithFriends.Resources;
using Megabonk.BonkWithFriends.Steam;
using Megabonk.BonkWithFriends.UI;
using Megabonk.BonkWithFriends.UI.Chat;
using Megabonk.BonkWithFriends.UI.Networking;
using Megabonk.BonkWithFriends.UI.SpawnSync;
using Microsoft.CodeAnalysis;
using Rewired;
using Semver;
using Steamworks;
using TMPro;
using TextCopy;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Events;
using UnityEngine.Localization;
using UnityEngine.Localization.Components;
using UnityEngine.Localization.Settings;
using UnityEngine.Localization.Tables;
using UnityEngine.Networking;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using Utility;

[assembly: CompilationRelaxations(8)]
[assembly: RuntimeCompatibility(WrapNonExceptionThrows = true)]
[assembly: Debuggable(DebuggableAttribute.DebuggingModes.IgnoreSymbolStoreSequencePoints)]
[assembly: TargetFramework(".NETCoreApp,Version=v6.0", FrameworkDisplayName = ".NET 6.0")]
[assembly: AssemblyCompany("Megabonk.BonkWithFriends")]
[assembly: AssemblyConfiguration("Release")]
[assembly: AssemblyFileVersion("0.3.2.0")]
[assembly: AssemblyInformationalVersion("0.3.2+cf2b2037b559f668c0c7cc24a9f29f5a07050a2e")]
[assembly: AssemblyProduct("Megabonk.BonkWithFriends")]
[assembly: AssemblyTitle("Megabonk.BonkWithFriends")]
[assembly: SecurityPermission(SecurityAction.RequestMinimum, SkipVerification = true)]
[assembly: AssemblyVersion("0.3.2.0")]
[module: UnverifiableCode]
[module: RefSafetyRules(11)]
namespace Microsoft.CodeAnalysis
{
	[CompilerGenerated]
	[Microsoft.CodeAnalysis.Embedded]
	internal sealed class EmbeddedAttribute : Attribute
	{
	}
}
namespace System.Runtime.CompilerServices
{
	[CompilerGenerated]
	[Microsoft.CodeAnalysis.Embedded]
	[AttributeUsage(AttributeTargets.Module, AllowMultiple = false, Inherited = false)]
	internal sealed class RefSafetyRulesAttribute : Attribute
	{
		public readonly int Version;

		public RefSafetyRulesAttribute(int P_0)
		{
			Version = P_0;
		}
	}
}
namespace Megabonk.BonkWithFriends
{
	[BepInPlugin("com.BWFTeam.BonkWithFriends", "BonkWithFriends", "0.3.2")]
	[BepInProcess("Megabonk.exe")]
	internal sealed class BonkWithFriendsMod : BasePlugin
	{
		internal delegate void OnSceneWasLoadedDelegate(int buildIndex, string sceneName);

		internal delegate void OnSceneWasInitializedDelegate(int buildIndex, string sceneName);

		internal delegate void OnSceneWasUnloadedDelegate(int buildIndex, string sceneName);

		private static class DataManagerLoadPatch1
		{
			private static void Postfix(DataManager __instance)
			{
				//IL_001f: Unknown result type (might be due to invalid IL or missing references)
				Dictionary<ECharacter, List<SkinData>> skinData = __instance.skinData;
				if (skinData == null)
				{
					return;
				}
				Enumerator<ECharacter, List<SkinData>> enumerator = skinData.GetEnumerator();
				while (enumerator.MoveNext())
				{
					KeyValuePair<ECharacter, List<SkinData>> current = enumerator.Current;
					if (current != null)
					{
						_ = current.Key;
						Enumerator<SkinData> enumerator2 = current.Value.GetEnumerator();
						while (enumerator2.MoveNext())
						{
							_ = (Object)(object)enumerator2.Current == (Object)null;
						}
					}
				}
			}
		}

		private static class MyPlayerStartPatch1
		{
			private static void Postfix(MyPlayer __instance)
			{
				_ = (Object)(object)((Component)__instance).gameObject == (Object)null;
			}
		}

		private static class EnemyAwakePatch1
		{
			private static void Postfix(Enemy __instance)
			{
				_ = (Object)(object)((Component)__instance).gameObject == (Object)null;
			}
		}

		private GameObject _managersGameObject;

		private SteamManager _steamManager;

		internal static OnSceneWasLoadedDelegate SceneWasLoaded;

		internal static OnSceneWasInitializedDelegate SceneWasInitialized;

		internal static OnSceneWasUnloadedDelegate SceneWasUnloaded;

		internal static BonkWithFriendsMod Instance { get; private set; }

		internal SynchronizationContext MainThreadSyncContext { get; private set; }

		public static bool IsSteamApiDllMissing { get; private set; }

		public override void Load()
		{
			//IL_004f: Unknown result type (might be due to invalid IL or missing references)
			if (Instance != null)
			{
				throw new InvalidOperationException("Instance");
			}
			Instance = this;
			ModLogger.Init(((BasePlugin)this).Log);
			MainThreadSyncContext = SynchronizationContext.Current;
			SetCustomDllImportResolver();
			Preferences.Init(((BasePlugin)this).Config);
			RegisterIl2CppTypes();
			SetupManagers();
			new Harmony("com.BWFTeam.BonkWithFriends").PatchAll();
			RunAllStaticConstructors();
			MultiplayerUIManager.Initialize();
			SceneManager.sceneLoaded += UnityAction<Scene, LoadSceneMode>.op_Implicit((Action<Scene, LoadSceneMode>)OnSceneLoaded);
			SceneManager.sceneUnloaded += UnityAction<Scene>.op_Implicit((Action<Scene>)OnSceneUnloaded);
		}

		private void SetCustomDllImportResolver()
		{
			NativeLibrary.SetDllImportResolver(Assembly.GetExecutingAssembly(), DllImportResolver);
			Assembly assembly = AppDomain.CurrentDomain.GetAssemblies().FirstOrDefault((Assembly a) => !a.FullName.Contains("il2cpp", StringComparison.OrdinalIgnoreCase) && a.FullName.Contains("Steamworks.NET", StringComparison.OrdinalIgnoreCase));
			if (assembly != null)
			{
				NativeLibrary.SetDllImportResolver(assembly, DllImportResolver);
			}
		}

		private static IntPtr DllImportResolver(string libraryName, Assembly assembly, DllImportSearchPath? searchPath)
		{
			if (string.IsNullOrWhiteSpace(libraryName))
			{
				return IntPtr.Zero;
			}
			string value = "steam_api";
			if (libraryName.Contains(value))
			{
				string currentDirectory = Directory.GetCurrentDirectory();
				if (string.IsNullOrWhiteSpace(currentDirectory) || !Directory.Exists(currentDirectory))
				{
					return IntPtr.Zero;
				}
				string[] source = new string[3] { ".dll", ".so", ".dylib" };
				foreach (string item in Directory.EnumerateFiles(currentDirectory, "*.*", SearchOption.TopDirectoryOnly))
				{
					string fileName = Path.GetFileName(item);
					if (!string.IsNullOrWhiteSpace(fileName) && fileName.Contains(value) && source.Any(fileName.EndsWith))
					{
						return NativeLibrary.Load(item);
					}
				}
				string path = Path.Combine(currentDirectory, "Plugins");
				if (Directory.Exists(path))
				{
					foreach (string item2 in Directory.EnumerateFiles(path, "*.*", SearchOption.TopDirectoryOnly))
					{
						string fileName2 = Path.GetFileName(item2);
						if (!string.IsNullOrWhiteSpace(fileName2) && fileName2.Contains(value) && source.Any(fileName2.EndsWith))
						{
							return NativeLibrary.Load(item2);
						}
					}
				}
			}
			IsSteamApiDllMissing = true;
			return IntPtr.Zero;
		}

		private static void RegisterIl2CppTypes()
		{
			Type[] types = Assembly.GetExecutingAssembly().GetTypes();
			foreach (Type type in types)
			{
				if (type.GetCustomAttribute<RegisterTypeInIl2CppAttribute>() != null)
				{
					ClassInjector.RegisterTypeInIl2Cpp(type);
				}
			}
		}

		private void SetupManagers()
		{
			//IL_0006: Unknown result type (might be due to invalid IL or missing references)
			//IL_0010: Expected O, but got Unknown
			_managersGameObject = new GameObject("BonkWithFriendsMod_Managers");
			Object.DontDestroyOnLoad((Object)(object)_managersGameObject);
			CoroutineRunner.Init(_managersGameObject);
			_steamManager = _managersGameObject.AddComponent<SteamManager>();
		}

		private static void RunAllStaticConstructors()
		{
			Type[] types = Assembly.GetExecutingAssembly().GetTypes();
			for (int i = 0; i < types.Length; i++)
			{
				RuntimeHelpers.RunClassConstructor(types[i].TypeHandle);
			}
		}

		private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
		{
			SceneWasLoaded?.Invoke(((Scene)(ref scene)).buildIndex, ((Scene)(ref scene)).name);
			SceneWasInitialized?.Invoke(((Scene)(ref scene)).buildIndex, ((Scene)(ref scene)).name);
			if (((Scene)(ref scene)).name == "GeneratedMap")
			{
				PlayerSceneManager.OnSceneLoaded(((Scene)(ref scene)).name);
			}
		}

		private void OnSceneUnloaded(Scene scene)
		{
			SceneWasUnloaded?.Invoke(((Scene)(ref scene)).buildIndex, ((Scene)(ref scene)).name);
			if (((Scene)(ref scene)).name == "GeneratedMap")
			{
				PlayerSceneManager.OnSceneUnloaded(((Scene)(ref scene)).name);
			}
		}
	}
	[RegisterTypeInIl2Cpp]
	internal sealed class CoroutineRunner : MonoBehaviour
	{
		private static CoroutineRunner _instance;

		public CoroutineRunner(IntPtr ptr)
			: base(ptr)
		{
		}

		public CoroutineRunner()
			: base(ClassInjector.DerivedConstructorPointer<CoroutineRunner>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		internal static void Init(GameObject parent)
		{
			_instance = parent.AddComponent<CoroutineRunner>();
		}

		[HideFromIl2Cpp]
		internal static Coroutine Start(IEnumerator routine)
		{
			return ((MonoBehaviour)_instance).StartCoroutine(CollectionExtensions.WrapToIl2Cpp(routine));
		}

		[HideFromIl2Cpp]
		internal static void Stop(Coroutine coroutine)
		{
			if (coroutine != null)
			{
				((MonoBehaviour)_instance).StopCoroutine(coroutine);
			}
		}

		[HideFromIl2Cpp]
		internal static void Stop(object coroutine)
		{
			Coroutine val = (Coroutine)((coroutine is Coroutine) ? coroutine : null);
			if (val != null)
			{
				((MonoBehaviour)_instance).StopCoroutine(val);
			}
		}
	}
	internal static class ModLogger
	{
		private static ManualLogSource _log;

		internal static void Init(ManualLogSource log)
		{
			_log = log;
		}

		[Conditional("DEBUG")]
		internal static void Msg(string message)
		{
			_log.LogInfo((object)message);
		}

		[Conditional("DEBUG")]
		internal static void Msg(object obj)
		{
			_log.LogInfo((object)obj?.ToString());
		}

		[Conditional("DEBUG")]
		internal static void Warning(string message)
		{
			_log.LogWarning((object)message);
		}

		internal static void Error(string message)
		{
			_log.LogError((object)message);
		}

		internal static void Error(Exception ex)
		{
			_log.LogError((object)ex);
		}

		internal static void Error(string message, Exception ex)
		{
			//IL_0009: Unknown result type (might be due to invalid IL or missing references)
			//IL_000f: Expected O, but got Unknown
			ManualLogSource log = _log;
			bool flag = default(bool);
			BepInExErrorLogInterpolatedStringHandler val = new BepInExErrorLogInterpolatedStringHandler(1, 2, ref flag);
			if (flag)
			{
				((BepInExLogInterpolatedStringHandler)val).AppendFormatted<string>(message);
				((BepInExLogInterpolatedStringHandler)val).AppendLiteral("\n");
				((BepInExLogInterpolatedStringHandler)val).AppendFormatted<Exception>(ex);
			}
			log.LogError(val);
		}
	}
	public static class Preferences
	{
		public static ConfigEntry<int> MaxPlayers;

		public static ConfigEntry<float> EnemySpawnRate;

		public static ConfigEntry<float> EnemyHpModifer;

		public static ConfigEntry<float> EnemyDmgModifer;

		public static ConfigEntry<float> EnemySpeedModifer;

		public static ConfigEntry<bool> LevelSync;

		public static ConfigEntry<bool> PauseSync;

		internal static void Init(ConfigFile config)
		{
			MaxPlayers = config.Bind<int>("General", "MaxPlayers", 4, "Max number of players in a match");
			EnemySpawnRate = config.Bind<float>("General", "EnemySpawnRate", 2f, "Enemy Spawn Multiplier");
			EnemyHpModifer = config.Bind<float>("General", "EnemyHpModifer", 1.5f, "Increases Enemy HP - 2.0f is double");
			EnemyDmgModifer = config.Bind<float>("General", "EnemyDmgModifer", 1f, "Increases Enemy Damage - 2.0f is double");
			EnemySpeedModifer = config.Bind<float>("General", "EnemySpeedModifer", 1f, "Increases Enemy Speed - 2.0f is double");
			LevelSync = config.Bind<bool>("General", "LevelSync", false, "Enable or disable sharing levels and XP");
			PauseSync = config.Bind<bool>("General", "PauseSync", false, "When enabled, your game will automatically pause whenever a friend pauses theirs.");
		}
	}
	[AttributeUsage(AttributeTargets.Class, Inherited = false)]
	internal sealed class RegisterTypeInIl2CppAttribute : Attribute
	{
	}
}
namespace Megabonk.BonkWithFriends.UI
{
	[RegisterTypeInIl2Cpp]
	public class Billboard : MonoBehaviour
	{
		private Transform _cameraTransform;

		public Billboard(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public Billboard()
			: base(ClassInjector.DerivedConstructorPointer<Billboard>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Start()
		{
			if ((Object)(object)Camera.main != (Object)null)
			{
				_cameraTransform = ((Component)Camera.main).transform;
			}
		}

		private void LateUpdate()
		{
			//IL_0014: Unknown result type (might be due to invalid IL or missing references)
			//IL_001f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0024: Unknown result type (might be due to invalid IL or missing references)
			//IL_0029: Unknown result type (might be due to invalid IL or missing references)
			//IL_002e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0039: Unknown result type (might be due to invalid IL or missing references)
			//IL_003e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0043: Unknown result type (might be due to invalid IL or missing references)
			if (_cameraTransform != null)
			{
				((Component)this).transform.LookAt(((Component)this).transform.position + _cameraTransform.rotation * Vector3.forward, _cameraTransform.rotation * Vector3.up);
			}
		}
	}
	internal static class CustomUiHelper
	{
		private static MyButtonNormal _myButtonNormalPrefab;

		private static GameObject _characterTabGameObject;

		private static MainMenu _mainMenuInstance;

		internal static bool Initialized { get; private set; }

		internal static void Setup(MainMenu instance)
		{
			_mainMenuInstance = instance;
			MyButton btnPlay = instance.btnPlay;
			if ((Object)(object)btnPlay == (Object)null)
			{
				ModLogger.Error("Setup playButton null");
				return;
			}
			_myButtonNormalPrefab = ((Il2CppObjectBase)btnPlay).Cast<MyButtonNormal>();
			_characterTabGameObject = instance.tabCharacters;
			if ((Object)(object)_characterTabGameObject == (Object)null)
			{
				ModLogger.Error("Setup _characterTabGameObject null");
			}
			else
			{
				Initialized = true;
			}
		}

		internal static MyButtonNormal CreateMyButtonNormal(Transform parent, string gameObjectName, string localizationTableName, string localizationTableEntryKey, Action onClick, int siblingIndex = -1, bool keepPersistentListeners = false, GameObject prefab = null)
		{
			if (!Initialized)
			{
				return null;
			}
			GameObject val = null;
			val = ((!((Object)(object)prefab == (Object)null)) ? Object.Instantiate<GameObject>(prefab, parent) : Object.Instantiate<GameObject>(((Component)_myButtonNormalPrefab).gameObject, parent));
			if ((Object)(object)val == (Object)null)
			{
				ModLogger.Error("CreateMyButtonNormal newMyButtonNormalGameObject null");
				return null;
			}
			((Object)val).name = gameObjectName;
			Transform transform = val.transform;
			if (siblingIndex > -1)
			{
				transform.SetSiblingIndex(siblingIndex);
			}
			((LocalizedReference)val.GetComponent<ResizeOnLocalization>().localizeStringEvent.StringReference).SetReference(TableReference.op_Implicit(localizationTableName), TableEntryReference.op_Implicit(localizationTableEntryKey));
			MyButtonNormal component = val.GetComponent<MyButtonNormal>();
			Button component2 = val.GetComponent<Button>();
			((UnityEventBase)component2.onClick).RemoveAllListeners();
			if (!keepPersistentListeners)
			{
				((UnityEventBase)component2.onClick).SetPersistentListenerState(0, (UnityEventCallState)0);
			}
			Action action = ((MyButton)component).OnClick;
			Action action2 = ((MyButton)component).PlaySfx;
			((UnityEvent)component2.onClick).AddListener(UnityAction.op_Implicit(action));
			((UnityEvent)component2.onClick).AddListener(UnityAction.op_Implicit(action2));
			((UnityEvent)component2.onClick).AddListener(UnityAction.op_Implicit(onClick));
			return component;
		}

		internal static void FixCustomMyButtonNormal(MyButtonNormal myButtonNormal)
		{
			GameObject gameObject = ((Component)myButtonNormal).gameObject;
			Transform transform = ((Component)gameObject.GetComponentInChildren<TMP_Text>()).gameObject.transform;
			((MyButton)myButtonNormal).scaleOnHover = transform;
			myButtonNormal.background = (MaskableGraphic)(object)gameObject.GetComponent<Image>();
		}

		internal static void Reset()
		{
			Initialized = false;
		}
	}
	internal static class CustomUiManager
	{
		[HarmonyPatch(typeof(MainMenu), "Start")]
		private static class MainMenuStartPatch1
		{
			private static void Postfix(MainMenu __instance)
			{
				try
				{
					LocalizationManager.Setup();
					MainMenu = __instance;
					CustomUiHelper.Setup(MainMenu);
					if (LoadCustomUiAssetBundle())
					{
						SetupCustomUi();
					}
					MultiplayerUI.ShowPopup();
				}
				catch (Exception ex)
				{
					ModLogger.Error(ex);
				}
			}
		}

		private const string CustomUiAssetBundleFileName = "bonkwithfriends.bwf";

		private const string CustomUiAssetBundleManifestFileName = "bonkwithfriends.bwf.manifest";

		internal static readonly bool UseEmbeddedCustomUi;

		internal static AssetBundle CustomUiAssetBundle;

		internal static GameObject CustomUiRootPrefab;

		internal static GameObject CustomUiRootGameObject;

		internal static Transform CustomUiRootTransform;

		internal static Transform NetworkLobbyUiTransform;

		internal static GameObject NetworkLobbyUiGameObject;

		internal static Canvas NetworkLobbyUiCanvas;

		internal static CanvasScaler NetworkLobbyUiCanvasScaler;

		internal static NetworkLobbyUi NetworkLobbyUi;

		internal static MyButtonNormal MultiplayerMyButtonNormal;

		internal static Transform MultiplayerButtonTransform;

		internal static GameObject MultiplayerButtonGameObject;

		private static Action<AsyncOperation> _onAssetBundleCreateRequestCompletedDelegate;

		private static Action<AsyncOperation> _onAssetBundleRequestCompletedDelegate;

		private static Il2CppStructArray<byte> _customUiAssetBundleBytesIl2CppArray;

		internal static MainMenu MainMenu { get; set; }

		static CustomUiManager()
		{
			UseEmbeddedCustomUi = true;
			BonkWithFriendsMod.SceneWasLoaded = (BonkWithFriendsMod.OnSceneWasLoadedDelegate)Delegate.Combine(BonkWithFriendsMod.SceneWasLoaded, new BonkWithFriendsMod.OnSceneWasLoadedDelegate(OnSceneWasLoaded));
			BonkWithFriendsMod.SceneWasInitialized = (BonkWithFriendsMod.OnSceneWasInitializedDelegate)Delegate.Combine(BonkWithFriendsMod.SceneWasInitialized, new BonkWithFriendsMod.OnSceneWasInitializedDelegate(OnSceneWasInitialized));
			BonkWithFriendsMod.SceneWasUnloaded = (BonkWithFriendsMod.OnSceneWasUnloadedDelegate)Delegate.Combine(BonkWithFriendsMod.SceneWasUnloaded, new BonkWithFriendsMod.OnSceneWasUnloadedDelegate(OnSceneWasUnloaded));
			_onAssetBundleCreateRequestCompletedDelegate = Action<AsyncOperation>.op_Implicit((Action<AsyncOperation>)OnAssetBundleCreateRequestCompleted);
			_onAssetBundleRequestCompletedDelegate = Action<AsyncOperation>.op_Implicit((Action<AsyncOperation>)OnAssetBundleRequestCompleted);
		}

		internal static bool LoadCustomUiAssetBundle()
		{
			//IL_0053: Unknown result type (might be due to invalid IL or missing references)
			//IL_005d: Expected O, but got Unknown
			if ((Object)(object)CustomUiRootPrefab != (Object)null && (Object)(object)CustomUiAssetBundle != (Object)null)
			{
				return true;
			}
			AssetBundleCreateRequest val = null;
			if (UseEmbeddedCustomUi)
			{
				byte[] customUiAssetBundleBytes = ResourceManager.CustomUiAssetBundleBytes;
				if (customUiAssetBundleBytes == null || customUiAssetBundleBytes.Length <= 0)
				{
					throw new NullReferenceException("CustomUiAssetBundleBytes");
				}
				_customUiAssetBundleBytesIl2CppArray = Il2CppStructArray<byte>.op_Implicit(ResourceManager.CustomUiAssetBundleBytes);
				val = AssetBundle.LoadFromStreamAsync((Stream)new MemoryStream(_customUiAssetBundleBytesIl2CppArray));
			}
			else
			{
				string text = Path.Combine(Directory.GetCurrentDirectory(), "bonkwithfriends.bwf");
				if (!File.Exists(text))
				{
					throw new FileNotFoundException(text);
				}
				val = AssetBundle.LoadFromFileAsync(text);
			}
			if (val != null)
			{
				((AsyncOperation)val).m_completeCallback = _onAssetBundleCreateRequestCompletedDelegate;
			}
			return false;
		}

		private static void OnAssetBundleCreateRequestCompleted(AsyncOperation operation)
		{
			AssetBundleCreateRequest obj = ((Il2CppObjectBase)operation).Cast<AssetBundleCreateRequest>();
			((AsyncOperation)obj).m_completeCallback = null;
			_onAssetBundleCreateRequestCompletedDelegate = null;
			CustomUiAssetBundle = obj.assetBundle;
			((Object)CustomUiAssetBundle).hideFlags = (HideFlags)32;
			((AsyncOperation)CustomUiAssetBundle.LoadAssetAsync<GameObject>("Assets/Prefabs/CustomUiRoot.prefab")).m_completeCallback = _onAssetBundleRequestCompletedDelegate;
		}

		private static void OnAssetBundleRequestCompleted(AsyncOperation operation)
		{
			AssetBundleRequest obj = ((Il2CppObjectBase)operation).Cast<AssetBundleRequest>();
			((AsyncOperation)obj).m_completeCallback = null;
			_onAssetBundleRequestCompletedDelegate = null;
			CustomUiRootPrefab = ((Il2CppObjectBase)obj.asset).Cast<GameObject>();
			((Object)CustomUiRootPrefab).hideFlags = (HideFlags)32;
			SetupCustomUi();
		}

		private static void SetupCustomUi()
		{
			CustomUiRootGameObject = Object.Instantiate<GameObject>(CustomUiRootPrefab);
			CustomUiRootTransform = CustomUiRootGameObject.transform;
			NetworkLobbyUiTransform = CustomUiRootTransform.Find("Canvas_NetworkLobby");
			NetworkLobbyUiGameObject = ((Component)NetworkLobbyUiTransform).gameObject;
			NetworkLobbyUiCanvas = NetworkLobbyUiGameObject.GetComponent<Canvas>();
			NetworkLobbyUiCanvasScaler = NetworkLobbyUiGameObject.GetComponent<CanvasScaler>();
			NetworkLobbyUi = NetworkLobbyUiGameObject.AddComponent<NetworkLobbyUi>();
			Transform transform = ((Component)MainMenu.btnPlay).gameObject.transform;
			MultiplayerMyButtonNormal = CustomUiHelper.CreateMyButtonNormal(transform.parent, "B_Multiplayer", LocalizationManager.MainMenu.TableName, ((TableEntry)LocalizationManager.MainMenu.Multiplayer).Key, OnMultiplayerButtonClick, transform.GetSiblingIndex() + 1);
			MultiplayerButtonGameObject = ((Component)MultiplayerMyButtonNormal).gameObject;
			MultiplayerButtonTransform = MultiplayerButtonGameObject.transform;
			Window activeWindow = WindowManager.activeWindow;
			if (activeWindow != null)
			{
				activeWindow.FindAllButtonsInWindow();
			}
			Window activeWindow2 = WindowManager.activeWindow;
			UiUtility.RebuildUi((activeWindow2 != null) ? ((Component)activeWindow2).transform : null);
		}

		private static void OnMultiplayerButtonClick()
		{
			NetworkLobbyUi?.OnMultiplayerButtonClick();
		}

		private static void OnSceneWasLoaded(int buildIndex, string sceneName)
		{
			switch (buildIndex)
			{
			case 1:
				OnMainMenuSceneLoadedOrInitialized(initialized: false);
				break;
			case 2:
				OnGeneratedLevelSceneLoadedOrInitialized(initialized: false);
				break;
			case 3:
				OnLoadingScreenSceneLoadedOrInitialized(initialized: false);
				break;
			case -1:
			case 0:
				break;
			}
		}

		private static void OnSceneWasInitialized(int buildIndex, string sceneName)
		{
			switch (buildIndex)
			{
			case 1:
				OnMainMenuSceneLoadedOrInitialized(initialized: true);
				break;
			case 2:
				OnGeneratedLevelSceneLoadedOrInitialized(initialized: true);
				break;
			case 3:
				OnLoadingScreenSceneLoadedOrInitialized(initialized: true);
				break;
			case -1:
			case 0:
				break;
			}
		}

		private static void OnMainMenuSceneLoadedOrInitialized(bool initialized)
		{
		}

		private static void OnGeneratedLevelSceneLoadedOrInitialized(bool initialized)
		{
		}

		private static void OnLoadingScreenSceneLoadedOrInitialized(bool initialized)
		{
		}

		private static void OnSceneWasUnloaded(int buildIndex, string sceneName)
		{
			switch (buildIndex)
			{
			case 1:
				OnMainMenuSceneUnloaded();
				break;
			case 2:
				OnGeneratedLevelSceneUnloaded();
				break;
			case 3:
				OnLoadingScreenSceneUnloaded();
				break;
			case -1:
			case 0:
				break;
			}
		}

		private static void OnMainMenuSceneUnloaded()
		{
			ResetCustomMainMenuUi();
		}

		private static void OnGeneratedLevelSceneUnloaded()
		{
		}

		private static void OnLoadingScreenSceneUnloaded()
		{
		}

		private static void ResetCustomMainMenuUi()
		{
		}
	}
	internal static class GuiCompat
	{
		private static GUIContent _emptyContent;

		private static GUIStyle _styleNone;

		public static GUIContent Empty
		{
			get
			{
				//IL_000e: Unknown result type (might be due to invalid IL or missing references)
				//IL_0013: Unknown result type (might be due to invalid IL or missing references)
				//IL_0019: Expected O, but got Unknown
				object obj = _emptyContent;
				if (obj == null)
				{
					GUIContent val = new GUIContent(string.Empty);
					_emptyContent = val;
					obj = (object)val;
				}
				return (GUIContent)obj;
			}
		}

		public static GUIStyle StyleNone
		{
			get
			{
				//IL_0009: Unknown result type (might be due to invalid IL or missing references)
				//IL_000e: Unknown result type (might be due to invalid IL or missing references)
				//IL_0014: Expected O, but got Unknown
				object obj = _styleNone;
				if (obj == null)
				{
					GUIStyle val = new GUIStyle();
					_styleNone = val;
					obj = (object)val;
				}
				return (GUIStyle)obj;
			}
		}
	}
	public class Helpers
	{
		public static bool ErrorIfNull<T>(T item, string errorMessage)
		{
			if (item == null)
			{
				ModLogger.Error(errorMessage);
				return true;
			}
			return false;
		}

		public static void DestroyAllChildren(Transform parent)
		{
			if ((Object)(object)parent == (Object)null)
			{
				return;
			}
			for (int i = 0; i < parent.childCount; i++)
			{
				Transform child = parent.GetChild(i);
				if ((Object)(object)child != (Object)null)
				{
					Object.Destroy((Object)(object)((Component)child).gameObject);
				}
			}
		}

		public static GameObject CreateButton(GameObject exampleButton, Transform parent, string objectName, string buttonLabel, UnityAction onClick)
		{
			//IL_00aa: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b4: Expected O, but got Unknown
			if (ErrorIfNull<GameObject>(exampleButton, "[HELPER] Example button was null!"))
			{
				return null;
			}
			GameObject val = Object.Instantiate<GameObject>(exampleButton, parent, false);
			((Object)val).name = objectName;
			Transform val2 = val.transform.Find("DisabledOverlay");
			if (Object.op_Implicit((Object)(object)val2))
			{
				((Component)val2).gameObject.SetActive(false);
			}
			Transform val3 = val.transform.Find("T_Text");
			TextMeshProUGUI val4 = ((!Object.op_Implicit((Object)(object)val3)) ? val.GetComponentInChildren<TextMeshProUGUI>(true) : ((Component)val3).GetComponent<TextMeshProUGUI>());
			((TMP_Text)val4).text = buttonLabel;
			LocalizeStringEvent component = ((Component)val4).GetComponent<LocalizeStringEvent>();
			if (Object.op_Implicit((Object)(object)component))
			{
				((Behaviour)component).enabled = false;
			}
			MyButtonNormal component2 = val.GetComponent<MyButtonNormal>();
			Button component3 = val.GetComponent<Button>();
			if ((Object)(object)component3 != (Object)null)
			{
				component3.onClick = new ButtonClickedEvent();
				((UnityEvent)component3.onClick).AddListener(onClick);
				((UnityEvent)component3.onClick).AddListener(UnityAction.op_Implicit((Action)((MyButton)component2).PlaySfx));
				((UnityEvent)component3.onClick).AddListener(UnityAction.op_Implicit((Action)((MyButton)component2).OnClick));
			}
			((Behaviour)component3).enabled = true;
			Selectable component4 = val.GetComponent<Selectable>();
			if (Object.op_Implicit((Object)(object)component4))
			{
				component4.OnDeselect((BaseEventData)null);
			}
			return val;
		}
	}
	public static class MultiplayerUI
	{
		private const string MOTD_URL = "https://gist.githubusercontent.com/HHG-r00tz/7e0bcb8576664f7b48a9012563ef56fd/raw";

		private const string MOTD_URL_NO_DLL = "https://gist.githubusercontent.com/HHG-r00tz/a7ff6a57a06a5cfe1cbebcac023014e0/raw";

		public static GameObject MultiplayerMenu;

		public static GameObject PopupWindow;

		public static GameObject LobbyMenu;

		public static GameObject LobbyName;

		private static readonly Dictionary<CSteamID, GameObject> MemberRows = new Dictionary<CSteamID, GameObject>();

		public static void ShowPopup()
		{
			if (Object.op_Implicit((Object)(object)PopupWindow))
			{
				return;
			}
			Transform val = GameObject.Find("UI").transform.Find("Tabs");
			Transform obj = val.Find("W_Credits");
			val.Find("Menu");
			PopupWindow = Object.Instantiate<GameObject>(((Component)obj).gameObject, val, false);
			((Object)PopupWindow).name = "BWFPopupWindow";
			Transform val2 = PopupWindow.transform.Find("Header/Header/T_Title");
			if (Object.op_Implicit((Object)(object)val2))
			{
				TextMeshProUGUI component = ((Component)val2).GetComponent<TextMeshProUGUI>();
				if (Object.op_Implicit((Object)(object)component))
				{
					LocalizeStringEvent component2 = ((Component)component).GetComponent<LocalizeStringEvent>();
					if (Object.op_Implicit((Object)(object)component2))
					{
						((Behaviour)component2).enabled = false;
					}
					((TMP_Text)component).text = "BonkWithFriends Notice";
				}
			}
			Transform val3 = PopupWindow.transform.Find("WindowLayers/Content/ScrollRect/ContentEntries/T_Title");
			if (Object.op_Implicit((Object)(object)val3))
			{
				TextMeshProUGUI component3 = ((Component)val3).GetComponent<TextMeshProUGUI>();
				if (Object.op_Implicit((Object)(object)component3))
				{
					((TMP_Text)component3).text = "Loading...";
					CoroutineRunner.Start(FetchMOTD(component3));
				}
			}
			Button component4 = ((Component)PopupWindow.transform.Find("Header/Header/B_Back")).GetComponent<Button>();
			((UnityEventBase)component4.onClick).SetPersistentListenerState(0, (UnityEventCallState)0);
			((Behaviour)component4).enabled = false;
			((Component)val3).gameObject.AddComponent<TMPLinkHandler>();
			PopupWindow.SetActive(true);
			Window activeWindow = WindowManager.activeWindow;
			if (activeWindow != null)
			{
				activeWindow.FindAllButtonsInWindow();
			}
		}

		private static IEnumerator FetchMOTD(TextMeshProUGUI textComponent)
		{
			UnityWebRequest request = ((!BonkWithFriendsMod.IsSteamApiDllMissing) ? UnityWebRequest.Get("https://gist.githubusercontent.com/HHG-r00tz/7e0bcb8576664f7b48a9012563ef56fd/raw") : UnityWebRequest.Get("https://gist.githubusercontent.com/HHG-r00tz/a7ff6a57a06a5cfe1cbebcac023014e0/raw"));
			yield return request.SendWebRequest();
			if ((int)request.result == 1)
			{
				((TMP_Text)textComponent).text = request.downloadHandler.text;
			}
			else
			{
				((TMP_Text)textComponent).text = "This mod is in pre-alpha development. Please bear this in mind.\n\n<color=red>Failed to load latest updates.</color>\n\nJoin our <link=\"https://discord.gg/Mxc8uFA8Nv\"><color=#5865F2><u>Discord</u></color></link>!";
			}
			CoroutineRunner.Start(HidePopupAfterDelay());
		}

		private static IEnumerator HidePopupAfterDelay()
		{
			if (BonkWithFriendsMod.IsSteamApiDllMissing)
			{
				yield return (object)new WaitForSeconds(20f);
				Application.Quit();
			}
			else
			{
				yield return (object)new WaitForSeconds(8f);
			}
			if (Object.op_Implicit((Object)(object)PopupWindow))
			{
				PopupWindow.SetActive(false);
				Object.Destroy((Object)(object)PopupWindow);
				PopupWindow = null;
			}
		}
	}
	public class MultiplayerUIManager : MonoBehaviour
	{
		public static MultiplayerUIManager Instance { get; private set; }

		public Canvas MainCanvas { get; private set; }

		public ChatWindowUi ChatWindow { get; private set; }

		public MultiplayerUIManager(IntPtr ptr)
			: base(ptr)
		{
		}

		public MultiplayerUIManager()
			: base(ClassInjector.DerivedConstructorPointer<MultiplayerUIManager>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		public static void Initialize()
		{
			//IL_001f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0024: Unknown result type (might be due to invalid IL or missing references)
			//IL_002a: Expected O, but got Unknown
			//IL_002a: Unknown result type (might be due to invalid IL or missing references)
			if (!((Object)(object)Instance != (Object)null))
			{
				if (!ClassInjector.IsTypeRegisteredInIl2Cpp<MultiplayerUIManager>())
				{
					ClassInjector.RegisterTypeInIl2Cpp<MultiplayerUIManager>();
				}
				GameObject val = new GameObject("BWF_MultiplayerUIManager");
				Object.DontDestroyOnLoad((Object)val);
				Instance = val.AddComponent<MultiplayerUIManager>();
				Instance.SetupCanvas();
				Instance.SetupChatWindow();
				val.AddComponent<NetProfilerGui>();
				BonkWithFriendsMod.SceneWasLoaded = (BonkWithFriendsMod.OnSceneWasLoadedDelegate)Delegate.Combine(BonkWithFriendsMod.SceneWasLoaded, new BonkWithFriendsMod.OnSceneWasLoadedDelegate(Instance.OnSceneLoaded));
			}
		}

		private void OnDestroy()
		{
			if ((Object)(object)Instance == (Object)(object)this)
			{
				BonkWithFriendsMod.SceneWasLoaded = (BonkWithFriendsMod.OnSceneWasLoadedDelegate)Delegate.Remove(BonkWithFriendsMod.SceneWasLoaded, new BonkWithFriendsMod.OnSceneWasLoadedDelegate(OnSceneLoaded));
				Instance = null;
			}
		}

		private void SetupCanvas()
		{
			//IL_004a: Unknown result type (might be due to invalid IL or missing references)
			MainCanvas = ((Component)this).gameObject.AddComponent<Canvas>();
			MainCanvas.renderMode = (RenderMode)0;
			MainCanvas.sortingOrder = 9999;
			CanvasScaler obj = ((Component)this).gameObject.AddComponent<CanvasScaler>();
			obj.uiScaleMode = (ScaleMode)1;
			obj.referenceResolution = new Vector2(1920f, 1080f);
			obj.matchWidthOrHeight = 0.5f;
			((Component)this).gameObject.AddComponent<GraphicRaycaster>();
		}

		private void SetupChatWindow()
		{
			//IL_0005: Unknown result type (might be due to invalid IL or missing references)
			//IL_000b: Expected O, but got Unknown
			//IL_0024: Unknown result type (might be due to invalid IL or missing references)
			//IL_002f: Unknown result type (might be due to invalid IL or missing references)
			//IL_003a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0044: Unknown result type (might be due to invalid IL or missing references)
			GameObject val = new GameObject("BWF_ChatWindow");
			val.transform.SetParent(((Component)this).transform, false);
			RectTransform obj = val.AddComponent<RectTransform>();
			obj.anchorMin = Vector2.zero;
			obj.anchorMax = Vector2.one;
			obj.offsetMin = Vector2.zero;
			obj.offsetMax = Vector2.zero;
			ChatWindow = val.AddComponent<ChatWindowUi>();
			val.SetActive(false);
		}

		private void OnSceneLoaded(int buildIndex, string sceneName)
		{
			bool flag = buildIndex == 2;
			bool flag2 = buildIndex == 1;
			if ((Object)(object)ChatWindow != (Object)null)
			{
				bool active = flag || flag2;
				((Component)ChatWindow).gameObject.SetActive(active);
			}
		}
	}
	[RegisterTypeInIl2Cpp]
	public class TMPLinkHandler : MonoBehaviour
	{
		private TMP_Text textComponent;

		private void Awake()
		{
			textComponent = ((Component)this).GetComponent<TMP_Text>();
		}

		private void Update()
		{
			//IL_0008: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0014: Unknown result type (might be due to invalid IL or missing references)
			if (Input.GetMouseButtonDown(0))
			{
				Vector3 mousePosition = Input.mousePosition;
				int num = TMP_TextUtilities.FindIntersectingLink(textComponent, mousePosition, (Camera)null);
				if (num != -1)
				{
					Application.OpenURL(((Il2CppArrayBase<TMP_LinkInfo>)(object)textComponent.textInfo.linkInfo)[num].GetLinkID());
				}
			}
		}
	}
	[RegisterTypeInIl2Cpp]
	public class ToastNotification : MonoBehaviour
	{
		private static ToastNotification _currentToast;

		private CanvasGroup _canvasGroup;

		private TextMeshProUGUI _text;

		private float _displayDuration = 3f;

		private float _fadeDuration = 0.3f;

		public ToastNotification(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public ToastNotification()
			: base(ClassInjector.DerivedConstructorPointer<ToastNotification>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		public static void Show(string message, float duration = 3f)
		{
			try
			{
				Canvas orCreateCanvas = GetOrCreateCanvas();
				if (!((Object)(object)orCreateCanvas == (Object)null))
				{
					if ((Object)(object)_currentToast != (Object)null)
					{
						Object.Destroy((Object)(object)((Component)_currentToast).gameObject);
						_currentToast = null;
					}
					ToastNotification toastNotification = CreateToastObject(((Component)orCreateCanvas).transform).AddComponent<ToastNotification>();
					toastNotification._displayDuration = duration;
					toastNotification.SetMessage(message);
					_currentToast = toastNotification;
				}
			}
			catch (Exception ex)
			{
				ModLogger.Error("[Toast] Failed to show toast: " + ex.Message);
			}
		}

		private static Canvas GetOrCreateCanvas()
		{
			GameObject val = GameObject.Find("UI");
			if ((Object)(object)val != (Object)null)
			{
				Canvas component = val.GetComponent<Canvas>();
				if ((Object)(object)component != (Object)null)
				{
					return component;
				}
			}
			Canvas val2 = Object.FindObjectOfType<Canvas>();
			if ((Object)(object)val2 != (Object)null)
			{
				return val2;
			}
			return null;
		}

		private static GameObject CreateToastObject(Transform parent)
		{
			//IL_0005: Unknown result type (might be due to invalid IL or missing references)
			//IL_000b: Expected O, but got Unknown
			//IL_0029: Unknown result type (might be due to invalid IL or missing references)
			//IL_003e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0053: Unknown result type (might be due to invalid IL or missing references)
			//IL_0068: Unknown result type (might be due to invalid IL or missing references)
			//IL_0072: Unknown result type (might be due to invalid IL or missing references)
			//IL_0091: Unknown result type (might be due to invalid IL or missing references)
			//IL_0096: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a8: Unknown result type (might be due to invalid IL or missing references)
			//IL_00af: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ba: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c5: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d0: Unknown result type (might be due to invalid IL or missing references)
			//IL_00da: Unknown result type (might be due to invalid IL or missing references)
			//IL_00fd: Unknown result type (might be due to invalid IL or missing references)
			//IL_010c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0111: Unknown result type (might be due to invalid IL or missing references)
			//IL_0123: Unknown result type (might be due to invalid IL or missing references)
			//IL_012a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0135: Unknown result type (might be due to invalid IL or missing references)
			//IL_0140: Unknown result type (might be due to invalid IL or missing references)
			//IL_0155: Unknown result type (might be due to invalid IL or missing references)
			//IL_0169: Unknown result type (might be due to invalid IL or missing references)
			//IL_0199: Unknown result type (might be due to invalid IL or missing references)
			GameObject val = new GameObject("BWF_Toast");
			val.transform.SetParent(parent, false);
			RectTransform obj = val.AddComponent<RectTransform>();
			obj.anchorMin = new Vector2(0.5f, 0.1f);
			obj.anchorMax = new Vector2(0.5f, 0.1f);
			obj.pivot = new Vector2(0.5f, 0.5f);
			obj.sizeDelta = new Vector2(600f, 60f);
			obj.anchoredPosition = Vector2.zero;
			val.AddComponent<CanvasGroup>().alpha = 0f;
			GameObject val2 = new GameObject("Background");
			val2.transform.SetParent(val.transform, false);
			RectTransform obj2 = val2.AddComponent<RectTransform>();
			obj2.anchorMin = Vector2.zero;
			obj2.anchorMax = Vector2.one;
			obj2.sizeDelta = Vector2.zero;
			obj2.offsetMin = Vector2.zero;
			obj2.offsetMax = Vector2.zero;
			((Graphic)val2.AddComponent<Image>()).color = new Color(0.1f, 0.1f, 0.1f, 0.9f);
			GameObject val3 = new GameObject("Text");
			val3.transform.SetParent(val.transform, false);
			RectTransform obj3 = val3.AddComponent<RectTransform>();
			obj3.anchorMin = Vector2.zero;
			obj3.anchorMax = Vector2.one;
			obj3.sizeDelta = Vector2.zero;
			obj3.offsetMin = new Vector2(20f, 10f);
			obj3.offsetMax = new Vector2(-20f, -10f);
			TextMeshProUGUI obj4 = val3.AddComponent<TextMeshProUGUI>();
			((TMP_Text)obj4).text = "";
			((TMP_Text)obj4).fontSize = 24f;
			((TMP_Text)obj4).alignment = (TextAlignmentOptions)514;
			((Graphic)obj4).color = Color.white;
			return val;
		}

		private void Awake()
		{
			_canvasGroup = ((Component)this).GetComponent<CanvasGroup>();
			_text = ((Component)this).GetComponentInChildren<TextMeshProUGUI>();
		}

		private void Start()
		{
			CoroutineRunner.Start(AnimateToast());
		}

		private void SetMessage(string message)
		{
			if ((Object)(object)_text != (Object)null)
			{
				((TMP_Text)_text).text = message;
			}
		}

		private IEnumerator AnimateToast()
		{
			float elapsed = 0f;
			while (elapsed < _fadeDuration)
			{
				elapsed += Time.unscaledDeltaTime;
				_canvasGroup.alpha = Mathf.Lerp(0f, 1f, elapsed / _fadeDuration);
				yield return null;
			}
			_canvasGroup.alpha = 1f;
			yield return (object)new WaitForSecondsRealtime(_displayDuration);
			elapsed = 0f;
			while (elapsed < _fadeDuration)
			{
				elapsed += Time.unscaledDeltaTime;
				_canvasGroup.alpha = Mathf.Lerp(1f, 0f, elapsed / _fadeDuration);
				yield return null;
			}
			if ((Object)(object)_currentToast == (Object)(object)this)
			{
				_currentToast = null;
			}
			Object.Destroy((Object)(object)((Component)this).gameObject);
		}
	}
}
namespace Megabonk.BonkWithFriends.UI.SpawnSync
{
	public static class SpawnSyncUI
	{
		private static TextMeshProUGUI _waitingText;

		private static float _dotAnimTimer;

		private static int _dotCount;

		public static void Show()
		{
			//IL_0015: Unknown result type (might be due to invalid IL or missing references)
			//IL_005e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0073: Unknown result type (might be due to invalid IL or missing references)
			//IL_0088: Unknown result type (might be due to invalid IL or missing references)
			//IL_009d: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b1: Unknown result type (might be due to invalid IL or missing references)
			//IL_00de: Unknown result type (might be due to invalid IL or missing references)
			//IL_010b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0110: Unknown result type (might be due to invalid IL or missing references)
			if ((Object)(object)_waitingText == (Object)null)
			{
				_waitingText = new GameObject("SpawnSyncWaitingText").AddComponent<TextMeshProUGUI>();
				Canvas val = Object.FindObjectOfType<Canvas>();
				if ((Object)(object)val != (Object)null)
				{
					((TMP_Text)_waitingText).transform.SetParent(((Component)val).transform, false);
				}
				RectTransform rectTransform = ((TMP_Text)_waitingText).rectTransform;
				rectTransform.anchorMin = new Vector2(0.5f, 0.5f);
				rectTransform.anchorMax = new Vector2(0.5f, 0.5f);
				rectTransform.pivot = new Vector2(0.5f, 0.5f);
				rectTransform.anchoredPosition = new Vector2(0f, 0f);
				rectTransform.sizeDelta = new Vector2(800f, 100f);
				((TMP_Text)_waitingText).alignment = (TextAlignmentOptions)514;
				((TMP_Text)_waitingText).fontSize = 48f;
				((Graphic)_waitingText).color = Color.white;
				((TMP_Text)_waitingText).text = "Waiting for other players";
				((TMP_Text)_waitingText).outlineWidth = 0.2f;
				((TMP_Text)_waitingText).outlineColor = Color32.op_Implicit(Color.black);
			}
			((Behaviour)_waitingText).enabled = true;
			_dotAnimTimer = 0f;
			_dotCount = 0;
		}

		public static void UpdateAnimation(float deltaTime)
		{
			if (!((Object)(object)_waitingText == (Object)null) && ((Behaviour)_waitingText).enabled)
			{
				_dotAnimTimer += deltaTime;
				if (_dotAnimTimer >= 1f)
				{
					_dotAnimTimer = 0f;
					_dotCount = (_dotCount + 1) % 4;
					string text = new string('.', _dotCount);
					((TMP_Text)_waitingText).text = "Waiting for other players" + text;
				}
			}
		}

		public static void Hide()
		{
			if ((Object)(object)_waitingText != (Object)null)
			{
				((Behaviour)_waitingText).enabled = false;
			}
		}

		public static void Destroy()
		{
			if ((Object)(object)_waitingText != (Object)null && (Object)(object)((Component)_waitingText).gameObject != (Object)null)
			{
				Object.Destroy((Object)(object)((Component)_waitingText).gameObject);
				_waitingText = null;
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.UI.Networking
{
	[RegisterTypeInIl2Cpp]
	public sealed class NetworkGameActionButtonsUi : MonoBehaviour
	{
		private Transform _characterSelectionButtonTransform;

		private GameObject _characterSelectionButtonGameObject;

		private Button _characterSelectionButton;

		private MyButtonNormal _characterSelectionMyButtonNormal;

		private UnityAction _onCharacterSelectionButtonClickedAction;

		private UnityAction _onCharacterSelectionConfirmClickedAction;

		private UnityAction _onCharacterSelectionBackClickedAction;

		private Transform _mapSelectionButtonTransform;

		private GameObject _mapSelectionButtonGameObject;

		private Button _mapSelectionButton;

		private MyButtonNormal _mapSelectionMyButtonNormal;

		private UnityAction _onMapSelectionButtonClickedAction;

		private UnityAction _onMapSelectionConfirmClickedAction;

		private UnityAction _onMapSelectionBackClickedAction;

		private Transform _readyButtonTransform;

		private GameObject _readyButtonGameObject;

		private Button _readyButton;

		private MyButtonNormal _readyMyButtonNormal;

		private UnityAction _onReadyButtonClickedAction;

		private TextMeshProUGUI _readybuttonTextTmp;

		private Transform _startButtonTransform;

		private GameObject _startButtonGameObject;

		private Button _startButton;

		private MyButtonNormal _startMyButtonNormal;

		private UnityAction _onStartButtonClickedAction;

		private Transform _backButtonTranform;

		private GameObject _backButtonGameObject;

		private Button _backButton;

		private MyButtonNormal _backButtonNormal;

		private UnityAction _onBackButtonClickedAction;

		private BackEscape _backBackEscape;

		private static HashSet<MethodInfo> _patchedMethods;

		private static MethodInfo _characterInfoUiOnCharacterSelectedMethodInfo;

		private static MethodInfo _onCharacterSelectedPostfixMethodInfo;

		private static HarmonyMethod _onCharacterSelectedPostfixHarmonyMethod;

		private bool _isStartMatchRunning;

		internal Window ParentWindow { get; set; }

		public NetworkGameActionButtonsUi(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public NetworkGameActionButtonsUi()
			: base(ClassInjector.DerivedConstructorPointer<NetworkGameActionButtonsUi>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			//IL_020b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0215: Expected O, but got Unknown
			_characterSelectionButtonTransform = ((Component)this).transform.Find("B_CharacterSelection");
			_characterSelectionButtonGameObject = ((Component)_characterSelectionButtonTransform).gameObject;
			_characterSelectionButton = _characterSelectionButtonGameObject.GetComponent<Button>();
			_characterSelectionMyButtonNormal = _characterSelectionButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_characterSelectionMyButtonNormal);
			_mapSelectionButtonTransform = ((Component)this).transform.Find("B_MapSelection");
			_mapSelectionButtonGameObject = ((Component)_mapSelectionButtonTransform).gameObject;
			_mapSelectionButton = _mapSelectionButtonGameObject.GetComponent<Button>();
			_mapSelectionMyButtonNormal = _mapSelectionButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_mapSelectionMyButtonNormal);
			_readyButtonTransform = ((Component)this).transform.Find("B_Ready");
			_readyButtonGameObject = ((Component)_readyButtonTransform).gameObject;
			_readyButton = _readyButtonGameObject.GetComponent<Button>();
			_readyMyButtonNormal = _readyButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_readyMyButtonNormal);
			_readybuttonTextTmp = _readyButtonGameObject.GetComponentInChildren<TextMeshProUGUI>();
			_startButtonTransform = ((Component)this).transform.Find("B_Start");
			_startButtonGameObject = ((Component)_startButtonTransform).gameObject;
			_startButton = _startButtonGameObject.GetComponent<Button>();
			_startMyButtonNormal = _startButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_startMyButtonNormal);
			_backButtonTranform = ((Component)this).transform.Find("B_Back");
			_backButtonGameObject = ((Component)_backButtonTranform).gameObject;
			_backButton = _backButtonGameObject.GetComponent<Button>();
			_backButtonNormal = _backButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_backButtonNormal);
			_backBackEscape = _backButtonGameObject.AddComponent<BackEscape>();
			_patchedMethods = new HashSet<MethodInfo>();
			_characterInfoUiOnCharacterSelectedMethodInfo = AccessTools.Method(typeof(CharacterInfoUI), "OnCharacterSelected", (Type[])null, (Type[])null);
			_onCharacterSelectedPostfixMethodInfo = AccessTools.Method(typeof(NetworkGameActionButtonsUi), "OnCharacterSelectedPostfix", (Type[])null, (Type[])null);
			_onCharacterSelectedPostfixHarmonyMethod = new HarmonyMethod(_onCharacterSelectedPostfixMethodInfo);
		}

		private void Start()
		{
			_onCharacterSelectionButtonClickedAction = UnityAction.op_Implicit((Action)OnCharacterSelectionButtonClicked);
			((UnityEvent)_characterSelectionButton.onClick).AddListener(_onCharacterSelectionButtonClickedAction);
			_onCharacterSelectionConfirmClickedAction = UnityAction.op_Implicit((Action)OnCharacterSelectionConfirmClicked);
			_onCharacterSelectionBackClickedAction = UnityAction.op_Implicit((Action)OnCharacterSelectionBackClicked);
			_onMapSelectionButtonClickedAction = UnityAction.op_Implicit((Action)OnMapSelectionButtonClicked);
			((UnityEvent)_mapSelectionButton.onClick).AddListener(_onMapSelectionButtonClickedAction);
			_onMapSelectionConfirmClickedAction = UnityAction.op_Implicit((Action)OnMapSelectionConfirmClicked);
			_onMapSelectionBackClickedAction = UnityAction.op_Implicit((Action)OnMapSelectionBackClicked);
			_onReadyButtonClickedAction = UnityAction.op_Implicit((Action)OnReadyButtonClicked);
			((UnityEvent)_readyButton.onClick).AddListener(_onReadyButtonClickedAction);
			SteamNetworkLobbyMember steamNetworkLobbyMember = SteamNetworkLobby.Instance?.GetMember(SteamManager.Instance.CurrentUserId);
			if (steamNetworkLobbyMember != null)
			{
				SetReadyButtonText(steamNetworkLobbyMember.IsReady);
			}
			else
			{
				SetReadyButtonText(isReady: false);
			}
			_onStartButtonClickedAction = UnityAction.op_Implicit((Action)OnStartButtonClicked);
			((UnityEvent)_startButton.onClick).AddListener(_onStartButtonClickedAction);
			_onBackButtonClickedAction = UnityAction.op_Implicit((Action)OnBackButtonClicked);
			((UnityEvent)_backButton.onClick).AddListener(_onBackButtonClickedAction);
		}

		private void OnCharacterSelectionButtonClicked()
		{
			//IL_0047: Unknown result type (might be due to invalid IL or missing references)
			//IL_0079: Unknown result type (might be due to invalid IL or missing references)
			MainMenu mainMenu = CustomUiManager.MainMenu;
			if (!((Object)(object)mainMenu == (Object)null))
			{
				CharacterMenu component = ((Component)mainMenu.tabCharacters.transform.Find("W_Character")).gameObject.GetComponent<CharacterMenu>();
				ButtonClickedEvent onClick = ((Component)component.b_confirm).gameObject.GetComponent<Button>().onClick;
				if ((int)((UnityEventBase)onClick).GetPersistentListenerState(0) != 0)
				{
					((UnityEventBase)onClick).SetPersistentListenerState(0, (UnityEventCallState)0);
				}
				((UnityEvent)onClick).AddListener(_onCharacterSelectionConfirmClickedAction);
				ButtonClickedEvent onClick2 = ((Component)component.b_back).gameObject.GetComponent<Button>().onClick;
				if ((int)((UnityEventBase)onClick2).GetPersistentListenerState(0) != 0)
				{
					((UnityEventBase)onClick2).SetPersistentListenerState(0, (UnityEventCallState)0);
				}
				((UnityEvent)onClick2).AddListener(_onCharacterSelectionBackClickedAction);
				mainMenu.GoToCharacterSelection();
			}
		}

		private void OnCharacterSelectionConfirmClicked()
		{
			//IL_0048: Unknown result type (might be due to invalid IL or missing references)
			//IL_004e: Invalid comparison between Unknown and I4
			//IL_0078: Unknown result type (might be due to invalid IL or missing references)
			//IL_007d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0089: Unknown result type (might be due to invalid IL or missing references)
			//IL_00cc: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d1: Unknown result type (might be due to invalid IL or missing references)
			//IL_00de: Unknown result type (might be due to invalid IL or missing references)
			MainMenu mainMenu = CustomUiManager.MainMenu;
			if ((Object)(object)mainMenu == (Object)null)
			{
				return;
			}
			CharacterMenu component = ((Component)mainMenu.tabCharacters.transform.Find("W_Character")).gameObject.GetComponent<CharacterMenu>();
			ButtonClickedEvent onClick = ((Component)component.b_confirm).gameObject.GetComponent<Button>().onClick;
			if ((int)((UnityEventBase)onClick).GetPersistentListenerState(0) != 2)
			{
				((UnityEventBase)onClick).SetPersistentListenerState(0, (UnityEventCallState)2);
			}
			((UnityEvent)onClick).RemoveListener(_onCharacterSelectionConfirmClickedAction);
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined)
			{
				return;
			}
			ECharacter eCharacter = component.selectedButton.characterData.eCharacter;
			SteamNetworkLobby.Instance?.MemberSetCharacter(eCharacter);
			SkinSelection skinSelection = component.skinSelection;
			int currentlySelected = skinSelection.currentlySelected;
			if (skinSelection.skins.Count >= currentlySelected)
			{
				SkinData val = skinSelection.skins[currentlySelected];
				if ((Object)(object)val != (Object)null)
				{
					ESkinType skinType = val.skinType;
					SteamNetworkLobby.Instance?.MemberSetSkinType(skinType);
				}
			}
			CoroutineRunner.Start(DelayedOnCharacterSelectionConfirmClicked());
		}

		private IEnumerator DelayedOnCharacterSelectionConfirmClicked()
		{
			for (int i = 0; i < 2; i++)
			{
				yield return (object)new WaitForEndOfFrame();
				NetworkLobbyUi.Instance?.GoToNetworkLobby();
			}
		}

		private void OnCharacterSelectionBackClicked()
		{
			//IL_0046: Unknown result type (might be due to invalid IL or missing references)
			//IL_004c: Invalid comparison between Unknown and I4
			MainMenu mainMenu = CustomUiManager.MainMenu;
			if (!((Object)(object)mainMenu == (Object)null))
			{
				ButtonClickedEvent onClick = ((Component)((Component)mainMenu.tabCharacters.transform.Find("W_Character")).gameObject.GetComponent<CharacterMenu>().b_back).gameObject.GetComponent<Button>().onClick;
				if ((int)((UnityEventBase)onClick).GetPersistentListenerState(0) != 2)
				{
					((UnityEventBase)onClick).SetPersistentListenerState(0, (UnityEventCallState)2);
				}
				((UnityEvent)onClick).RemoveListener(_onCharacterSelectionBackClickedAction);
				CoroutineRunner.Start(DelayedOnCharacterSelectionBackClicked());
			}
		}

		private IEnumerator DelayedOnCharacterSelectionBackClicked()
		{
			for (int i = 0; i < 2; i++)
			{
				yield return (object)new WaitForEndOfFrame();
				NetworkLobbyUi.Instance?.GoToNetworkLobby();
			}
		}

		private static void OnCharacterSelectedPostfix(CharacterInfoUI __instance, MyButtonCharacter btn)
		{
			_ = SteamNetworkLobbyManager.State;
			_ = 5;
		}

		private void OnMapSelectionButtonClicked()
		{
			//IL_0050: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a5: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			MainMenu mainMenu = CustomUiManager.MainMenu;
			if (!((Object)(object)mainMenu == (Object)null))
			{
				Transform obj = mainMenu.tabMaps.transform.Find("Maps And Stats");
				ButtonClickedEvent onClick = ((Component)((Component)obj).gameObject.GetComponent<MapSelectionUi>().btnConfirm).gameObject.GetComponent<Button>().onClick;
				if ((int)((UnityEventBase)onClick).GetPersistentListenerState(0) != 0)
				{
					((UnityEventBase)onClick).SetPersistentListenerState(0, (UnityEventCallState)0);
				}
				((UnityEvent)onClick).AddListener(_onMapSelectionConfirmClickedAction);
				ButtonClickedEvent onClick2 = ((Component)obj.Find("W_Maps").Find("Header").Find("Header")
					.Find("B_Back")).gameObject.GetComponent<Button>().onClick;
				if ((int)((UnityEventBase)onClick2).GetPersistentListenerState(0) != 0)
				{
					((UnityEventBase)onClick2).SetPersistentListenerState(0, (UnityEventCallState)0);
				}
				((UnityEvent)onClick2).AddListener(_onMapSelectionBackClickedAction);
				mainMenu.GoToMapSelection();
			}
		}

		private void OnMapSelectionConfirmClicked()
		{
			//IL_0048: Unknown result type (might be due to invalid IL or missing references)
			//IL_004e: Invalid comparison between Unknown and I4
			//IL_00a9: Unknown result type (might be due to invalid IL or missing references)
			MainMenu mainMenu = CustomUiManager.MainMenu;
			if ((Object)(object)mainMenu == (Object)null)
			{
				return;
			}
			MapSelectionUi component = ((Component)mainMenu.tabMaps.transform.Find("Maps And Stats")).gameObject.GetComponent<MapSelectionUi>();
			ButtonClickedEvent onClick = ((Component)component.btnConfirm).gameObject.GetComponent<Button>().onClick;
			if ((int)((UnityEventBase)onClick).GetPersistentListenerState(0) != 2)
			{
				((UnityEventBase)onClick).SetPersistentListenerState(0, (UnityEventCallState)2);
			}
			((UnityEvent)onClick).RemoveListener(_onMapSelectionConfirmClickedAction);
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined)
			{
				SteamNetworkLobby instance = SteamNetworkLobby.Instance;
				if (instance != null && instance.OwnedByUs())
				{
					RunConfig runConfig = component.runConfig;
					MapData mapData = runConfig.mapData;
					int mapTierIndex = runConfig.mapTierIndex;
					ChallengeData challenge = runConfig.challenge;
					SteamNetworkLobby.Instance?.SetMap(mapData.eMap);
					SteamNetworkLobby.Instance?.SetTier(mapTierIndex);
					SteamNetworkLobby.Instance?.SetChallenge(challenge);
					CoroutineRunner.Start(DelayedOnMapSelectionConfirmClicked());
				}
			}
		}

		private IEnumerator DelayedOnMapSelectionConfirmClicked()
		{
			yield return (object)new WaitForEndOfFrame();
			NetworkLobbyUi.Instance?.GoToNetworkLobby();
		}

		private void OnMapSelectionBackClicked()
		{
			//IL_0066: Unknown result type (might be due to invalid IL or missing references)
			//IL_006c: Invalid comparison between Unknown and I4
			MainMenu mainMenu = CustomUiManager.MainMenu;
			if (!((Object)(object)mainMenu == (Object)null))
			{
				Transform obj = mainMenu.tabMaps.transform.Find("Maps And Stats");
				_ = ((Component)obj).gameObject;
				ButtonClickedEvent onClick = ((Component)obj.Find("W_Maps").Find("Header").Find("Header")
					.Find("B_Back")).gameObject.GetComponent<Button>().onClick;
				if ((int)((UnityEventBase)onClick).GetPersistentListenerState(0) != 2)
				{
					((UnityEventBase)onClick).SetPersistentListenerState(0, (UnityEventCallState)2);
				}
				((UnityEvent)onClick).RemoveListener(_onMapSelectionBackClickedAction);
				CoroutineRunner.Start(DelayedOnMapSelectionBackClicked());
			}
		}

		private IEnumerator DelayedOnMapSelectionBackClicked()
		{
			yield return (object)new WaitForEndOfFrame();
			NetworkLobbyUi.Instance?.GoToNetworkLobby();
		}

		private void OnReadyButtonClicked()
		{
			SteamNetworkLobbyMember member = SteamNetworkLobby.Instance.GetMember(SteamManager.Instance.CurrentUserId);
			if (member == null)
			{
				return;
			}
			bool flag = !member.IsReady;
			if (flag)
			{
				string text = ValidateCanReady(member);
				if (!string.IsNullOrEmpty(text))
				{
					ToastNotification.Show(text);
					return;
				}
			}
			SteamNetworkLobby.Instance?.MemberSetReady(flag);
			SetReadyButtonText(flag);
			if (!_isStartMatchRunning)
			{
				CoroutineRunner.Start(StartMatch());
			}
		}

		private string ValidateCanReady(SteamNetworkLobbyMember member)
		{
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			if (!member.HasSelectedCharacter)
			{
				return "Please select a character first";
			}
			SteamNetworkLobby instance = SteamNetworkLobby.Instance;
			if (instance != null && instance.OwnedByUs() && (int)SteamNetworkLobby.Instance.Map == 0)
			{
				return "Please select a map first";
			}
			return null;
		}

		private void OnStartButtonClicked()
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined)
			{
				_ = SteamNetworkLobby.Instance?.OwnedByUs() ?? false;
			}
		}

		private IEnumerator StartMatch()
		{
			_isStartMatchRunning = true;
			try
			{
				if (SteamNetworkLobby.Instance != null && SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined)
				{
					while (!SteamNetworkLobby.Instance.AreAllMembersReady() || SteamNetworkLobby.Instance.MemberCount < 2)
					{
						yield return (object)new WaitForSeconds(0.1f);
					}
					yield return null;
					EMap map = SteamNetworkLobby.Instance.Map;
					int tier = SteamNetworkLobby.Instance.Tier;
					MapData map2 = DataManager.Instance.GetMap(map);
					StageData stageData = ((Il2CppArrayBase<StageData>)(object)map2.stages)[tier];
					RunConfig val = new RunConfig
					{
						mapData = map2,
						stageData = stageData,
						mapTierIndex = tier,
						challenge = null,
						musicTrackIndex = -1
					};
					if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
					{
						SteamNetworkLobby.Instance.LobbyType = SteamNetworkLobbyType.Private;
					}
					MapController.StartNewMap(val);
				}
			}
			finally
			{
				_isStartMatchRunning = false;
			}
		}

		private void StopStartMatchCoroutine()
		{
			if (_isStartMatchRunning)
			{
				CoroutineRunner.Stop((object)StartMatch());
				_isStartMatchRunning = false;
			}
		}

		private void OnBackButtonClicked()
		{
			StopStartMatchCoroutine();
			NetworkLobbyWindowUi.Instance?.HideGameActionButtons();
		}

		private void OnEnable()
		{
			CoroutineRunner.Start(DelayedOnEnable());
		}

		private IEnumerator DelayedOnEnable()
		{
			yield return (object)new WaitForEndOfFrame();
			NetworkLobbyWindowUi.Instance?.SetNetworkLobbyUiType(NetworkLobbyUiType.NetworkGameLobby);
			SteamNetworkLobby.Instance?.SetNetworkLobbyUiType(NetworkLobbyUiType.NetworkGameLobby);
			Window parentWindow = ParentWindow;
			if (parentWindow != null)
			{
				parentWindow.startBtn = (MyButton)(object)_characterSelectionMyButtonNormal;
			}
			Window parentWindow2 = ParentWindow;
			if (parentWindow2 != null)
			{
				parentWindow2.alwaysUseStartBtn = true;
			}
			Window parentWindow3 = ParentWindow;
			if (parentWindow3 != null)
			{
				parentWindow3.FindAllButtonsInWindow();
			}
			Window parentWindow4 = ParentWindow;
			if (parentWindow4 != null)
			{
				parentWindow4.DelayedButtonFocus();
			}
			UiUtility.RebuildUi(((Component)this).transform.parent);
		}

		private void SetReadyButtonText(bool isReady)
		{
			if (isReady)
			{
				((TMP_Text)_readybuttonTextTmp).text = "Unready";
			}
			else
			{
				((TMP_Text)_readybuttonTextTmp).text = "Ready";
			}
		}

		private void OnDestroy()
		{
			StopStartMatchCoroutine();
			((UnityEvent)_characterSelectionButton.onClick).RemoveListener(_onCharacterSelectionButtonClickedAction);
			((UnityEvent)_mapSelectionButton.onClick).RemoveListener(_onMapSelectionButtonClickedAction);
			((UnityEvent)_readyButton.onClick).RemoveListener(_onReadyButtonClickedAction);
			((UnityEvent)_startButton.onClick).RemoveListener(_onStartButtonClickedAction);
			((UnityEvent)_backButton.onClick).RemoveListener(_onBackButtonClickedAction);
		}
	}
	[RegisterTypeInIl2Cpp]
	public sealed class NetworkGameButtonsUi : MonoBehaviour
	{
		private Transform _createMultiplayerGameButtonTransform;

		private GameObject _createMultiplayerGameButtonGameObject;

		private Button _createMultiplayerGameButton;

		private MyButtonNormal _createMultiplayerGameMyButtonNormal;

		private UnityAction _onCreateMultiplayerGameButtonClickedAction;

		private Transform _joinMultiplayerGameButtonTransform;

		private GameObject _joinMultiplayerGameButtonGameObject;

		private Button _joinMultiplayerGameButton;

		private MyButtonNormal _joinMultiplayerGameMyButtonNormal;

		private UnityAction _onJoinMultiplayerGameButtonClickedAction;

		private Transform _backButtonTranform;

		private GameObject _backButtonGameObject;

		private Button _backButton;

		private MyButtonNormal _backButtonNormal;

		private UnityAction _onBackButtonClickedAction;

		private BackEscape _backBackEscape;

		internal Window ParentWindow { get; set; }

		public NetworkGameButtonsUi(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public NetworkGameButtonsUi()
			: base(ClassInjector.DerivedConstructorPointer<NetworkGameButtonsUi>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			_createMultiplayerGameButtonTransform = ((Component)this).transform.Find("B_CreateMultiplayerGame");
			_createMultiplayerGameButtonGameObject = ((Component)_createMultiplayerGameButtonTransform).gameObject;
			_createMultiplayerGameButton = _createMultiplayerGameButtonGameObject.GetComponent<Button>();
			_createMultiplayerGameMyButtonNormal = _createMultiplayerGameButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_createMultiplayerGameMyButtonNormal);
			_joinMultiplayerGameButtonTransform = ((Component)this).transform.Find("B_JoinMultiplayerGame");
			_joinMultiplayerGameButtonGameObject = ((Component)_joinMultiplayerGameButtonTransform).gameObject;
			_joinMultiplayerGameButton = _joinMultiplayerGameButtonGameObject.GetComponent<Button>();
			_joinMultiplayerGameMyButtonNormal = _joinMultiplayerGameButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_joinMultiplayerGameMyButtonNormal);
			_backButtonTranform = ((Component)this).transform.Find("B_Back");
			_backButtonGameObject = ((Component)_backButtonTranform).gameObject;
			_backButton = _backButtonGameObject.GetComponent<Button>();
			_backButtonNormal = _backButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_backButtonNormal);
			_backBackEscape = _backButtonGameObject.AddComponent<BackEscape>();
		}

		private void Start()
		{
			_onCreateMultiplayerGameButtonClickedAction = UnityAction.op_Implicit((Action)OnCreateMultiplayerGameButtonClicked);
			((UnityEvent)_createMultiplayerGameButton.onClick).AddListener(_onCreateMultiplayerGameButtonClickedAction);
			_onJoinMultiplayerGameButtonClickedAction = UnityAction.op_Implicit((Action)OnJoinMultiplayerGameButtonClicked);
			((UnityEvent)_joinMultiplayerGameButton.onClick).AddListener(_onJoinMultiplayerGameButtonClickedAction);
			_onBackButtonClickedAction = UnityAction.op_Implicit((Action)OnBackButtonClicked);
			((UnityEvent)_backButton.onClick).AddListener(_onBackButtonClickedAction);
		}

		private void OnCreateMultiplayerGameButtonClicked()
		{
			if (SteamManager.Instance?.Lobby != null)
			{
				SteamNetworkLobby.Instance.LobbyType = SteamNetworkLobbyType.FriendsOnly;
				NetworkLobbyWindowUi.Instance?.ShowGameActionButtons();
			}
		}

		private void OnJoinMultiplayerGameButtonClicked()
		{
		}

		private void OnBackButtonClicked()
		{
			NetworkLobbyWindowUi.Instance?.SetNetworkLobbyUiType(NetworkLobbyUiType.NetworkLobby);
			SteamManager instance = SteamManager.Instance;
			if ((Object)(object)instance != (Object)null)
			{
				SteamNetworkLobby lobby = instance.Lobby;
				if (lobby != null && lobby.MemberCount > 1)
				{
					SteamNetworkLobbyManager.LeaveLobby();
				}
			}
			CustomUiManager.MainMenu.GoToMenu();
		}

		private void OnEnable()
		{
			CoroutineRunner.Start(DelayedOnEnable());
		}

		private IEnumerator DelayedOnEnable()
		{
			yield return (object)new WaitForEndOfFrame();
			NetworkLobbyWindowUi.Instance?.SetNetworkLobbyUiType(NetworkLobbyUiType.NetworkLobby);
			SteamNetworkLobby.Instance?.SetNetworkLobbyUiType(NetworkLobbyUiType.NetworkLobby);
			Window parentWindow = ParentWindow;
			if (parentWindow != null)
			{
				parentWindow.startBtn = (MyButton)(object)_createMultiplayerGameMyButtonNormal;
			}
			Window parentWindow2 = ParentWindow;
			if (parentWindow2 != null)
			{
				parentWindow2.alwaysUseStartBtn = true;
			}
			Window parentWindow3 = ParentWindow;
			if (parentWindow3 != null)
			{
				parentWindow3.FindAllButtonsInWindow();
			}
			Window parentWindow4 = ParentWindow;
			if (parentWindow4 != null)
			{
				parentWindow4.DelayedButtonFocus();
			}
			UiUtility.RebuildUi(((Component)this).transform.parent);
		}

		private void OnDestroy()
		{
			((UnityEvent)_createMultiplayerGameButton.onClick).RemoveListener(_onCreateMultiplayerGameButtonClickedAction);
			((UnityEvent)_joinMultiplayerGameButton.onClick).RemoveListener(_onJoinMultiplayerGameButtonClickedAction);
			((UnityEvent)_backButton.onClick).RemoveListener(_onBackButtonClickedAction);
		}
	}
	[RegisterTypeInIl2Cpp]
	public sealed class NetworkLobbyButtonsUi : MonoBehaviour
	{
		private Transform _leaveLobbyButtonTransform;

		private GameObject _leaveLobbyButtonGameObject;

		private Button _leaveLobbyButton;

		private MyButtonNormal _leaveLobbyMyButtonNormal;

		private UnityAction _onLeaveLobbyButtonClickedAction;

		private Transform _copyLobbyToClipboardButtonTransform;

		private GameObject _copyLobbyToClipboardButtonGameObject;

		private Button _copyLobbyToClipboardButton;

		private MyButtonNormal _copyLobbyToClipboardMyButtonNormal;

		private UnityAction _onCopyLobbyToClipboardButtonClickedAction;

		private Transform _joinLobbyFromClipboardButtonTransform;

		private GameObject _joinLobbyFromClipboardButtonGameObject;

		private Button _joinLobbyFromClipboardButton;

		private MyButtonNormal _joinLobbyFromClipboardMyButtonNormal;

		private UnityAction _onJoinLobbyFromClipboardButtonClickedAction;

		public NetworkLobbyButtonsUi(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public NetworkLobbyButtonsUi()
			: base(ClassInjector.DerivedConstructorPointer<NetworkLobbyButtonsUi>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			_leaveLobbyButtonTransform = ((Component)this).transform.Find("B_LeaveLobby");
			_leaveLobbyButtonGameObject = ((Component)_leaveLobbyButtonTransform).gameObject;
			_leaveLobbyButton = _leaveLobbyButtonGameObject.GetComponent<Button>();
			_leaveLobbyMyButtonNormal = _leaveLobbyButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_leaveLobbyMyButtonNormal);
			_copyLobbyToClipboardButtonTransform = ((Component)this).transform.Find("B_CopyLobbyToClipboard");
			_copyLobbyToClipboardButtonGameObject = ((Component)_copyLobbyToClipboardButtonTransform).gameObject;
			_copyLobbyToClipboardButton = _copyLobbyToClipboardButtonGameObject.GetComponent<Button>();
			_copyLobbyToClipboardMyButtonNormal = _copyLobbyToClipboardButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_copyLobbyToClipboardMyButtonNormal);
			_joinLobbyFromClipboardButtonTransform = ((Component)this).transform.Find("B_JoinLobbyFromClipboard");
			_joinLobbyFromClipboardButtonGameObject = ((Component)_joinLobbyFromClipboardButtonTransform).gameObject;
			_joinLobbyFromClipboardButton = _joinLobbyFromClipboardButtonGameObject.GetComponent<Button>();
			_joinLobbyFromClipboardMyButtonNormal = _joinLobbyFromClipboardButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_joinLobbyFromClipboardMyButtonNormal);
		}

		private void Start()
		{
			_onLeaveLobbyButtonClickedAction = UnityAction.op_Implicit((Action)OnLeaveLobbyButtonClicked);
			((UnityEvent)_leaveLobbyButton.onClick).AddListener(_onLeaveLobbyButtonClickedAction);
			_onCopyLobbyToClipboardButtonClickedAction = UnityAction.op_Implicit((Action)OnCopyLobbyToClipboardButtonClicked);
			((UnityEvent)_copyLobbyToClipboardButton.onClick).AddListener(_onCopyLobbyToClipboardButtonClickedAction);
			_onJoinLobbyFromClipboardButtonClickedAction = UnityAction.op_Implicit((Action)OnJoinLobbyFromClipboardButtonClicked);
			((UnityEvent)_joinLobbyFromClipboardButton.onClick).AddListener(_onJoinLobbyFromClipboardButtonClickedAction);
		}

		private void OnLeaveLobbyButtonClicked()
		{
			SteamNetworkLobbyManager.LeaveLobby();
		}

		private void OnCopyLobbyToClipboardButtonClicked()
		{
			SteamManager instance = SteamManager.Instance;
			if (!((Object)(object)instance == (Object)null))
			{
				SteamNetworkLobby lobby = instance.Lobby;
				if (lobby != null && !(lobby.LobbyId == CSteamID.Nil))
				{
					ClipboardService.SetText(lobby.LobbyId.ToString());
				}
			}
		}

		private void OnJoinLobbyFromClipboardButtonClicked()
		{
			string text = ClipboardService.GetText();
			if (!string.IsNullOrWhiteSpace(text) && ulong.TryParse(text, out var result))
			{
				CSteamID cSteamID = new CSteamID(result);
				if (!(cSteamID == CSteamID.Nil))
				{
					SteamNetworkLobbyManager.JoinLobby(cSteamID);
				}
			}
		}

		private void OnDestroy()
		{
			((UnityEvent)_leaveLobbyButton.onClick).RemoveListener(_onLeaveLobbyButtonClickedAction);
			((UnityEvent)_copyLobbyToClipboardButton.onClick).RemoveListener(_onCopyLobbyToClipboardButtonClickedAction);
			((UnityEvent)_joinLobbyFromClipboardButton.onClick).RemoveListener(_onJoinLobbyFromClipboardButtonClickedAction);
		}
	}
	[RegisterTypeInIl2Cpp]
	public sealed class NetworkLobbyInviteMemberUi : MonoBehaviour
	{
		private Transform _inviteButtonTransform;

		private GameObject _inviteButtonGameObject;

		private Button _inviteButton;

		private MyButtonNormal _inviteMyButtonNormal;

		private UnityAction _onInviteButtonClickedAction;

		internal Window ParentWindow { get; set; }

		public NetworkLobbyInviteMemberUi(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public NetworkLobbyInviteMemberUi()
			: base(ClassInjector.DerivedConstructorPointer<NetworkLobbyInviteMemberUi>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			_inviteButtonTransform = ((Component)this).transform.Find("B_Invite");
			_inviteButtonGameObject = ((Component)_inviteButtonTransform).gameObject;
			_inviteButton = _inviteButtonGameObject.GetComponent<Button>();
			_inviteMyButtonNormal = _inviteButtonGameObject.AddComponent<MyButtonNormal>();
			CustomUiHelper.FixCustomMyButtonNormal(_inviteMyButtonNormal);
		}

		private void Start()
		{
			_onInviteButtonClickedAction = UnityAction.op_Implicit((Action)OnInviteButtonClicked);
			((UnityEvent)_inviteButton.onClick).AddListener(_onInviteButtonClickedAction);
		}

		private void OnInviteButtonClicked()
		{
			SteamNetworkLobby lobby = SteamManager.Instance.Lobby;
			if (lobby != null && lobby.LobbyId != CSteamID.Nil)
			{
				SteamFriends.ActivateGameOverlayInviteDialog(lobby.LobbyId);
			}
		}

		private void OnDestroy()
		{
			((UnityEvent)_inviteButton.onClick).RemoveListener(_onInviteButtonClickedAction);
		}
	}
	[RegisterTypeInIl2Cpp]
	public sealed class NetworkLobbyMemberUi : MonoBehaviour
	{
		private const int KickBanDropdownOptionNone = 0;

		private const int KickBanDropdownOptionKick = 1;

		private const int KickBanDropdownOptionBan = 2;

		private Transform _avatarReadyContainerTransform;

		private GameObject _avatarReadyContainerGameObject;

		private Transform _avatarImageTransform;

		private GameObject _avatarImageGameObject;

		private RawImage _avatarImage;

		private Transform _readyImageTransform;

		private GameObject _readyImageGameObject;

		private RawImage _readyImage;

		private Transform _notReadyImageTransform;

		private GameObject _notReadyImageGameObject;

		private RawImage _notReadyImage;

		private Transform _nameTmpTextTransform;

		private GameObject _nameTmpTextGameObject;

		private TextMeshProUGUI _nameTmpText;

		private Transform _containerTransform;

		private GameObject _containerGameObject;

		private Transform _kickBanDropdownTransform;

		private GameObject _kickBanTmpDropdownGameObject;

		private TMP_Dropdown _kickBanTmpDropdown;

		private UnityAction<int> _onKickBanDropdownValueChangedAction;

		private Transform _hostImageTransform;

		private GameObject _hostImageGameObject;

		private Image _hostImage;

		private SteamNetworkLobbyMember _steamNetworkLobbyMember;

		private NetworkLobbyUiType _networkLobbyUiType;

		public NetworkLobbyMemberUi(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public NetworkLobbyMemberUi()
			: base(ClassInjector.DerivedConstructorPointer<NetworkLobbyMemberUi>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			_avatarReadyContainerTransform = ((Component)this).transform.Find("C_AvatarReady");
			_avatarReadyContainerGameObject = ((Component)_avatarReadyContainerTransform).gameObject;
			_avatarImageTransform = _avatarReadyContainerTransform.Find("I_Avatar");
			_avatarImageGameObject = ((Component)_avatarImageTransform).gameObject;
			_avatarImage = _avatarImageGameObject.GetComponent<RawImage>();
			_readyImageTransform = _avatarReadyContainerTransform.Find("I_Ready");
			_readyImageGameObject = ((Component)_readyImageTransform).gameObject;
			_readyImage = _readyImageGameObject.GetComponent<RawImage>();
			_notReadyImageTransform = _avatarReadyContainerTransform.Find("I_NotReady");
			_notReadyImageGameObject = ((Component)_notReadyImageTransform).gameObject;
			_notReadyImage = _notReadyImageGameObject.GetComponent<RawImage>();
			_nameTmpTextTransform = ((Component)this).transform.Find("TMP_Name");
			_nameTmpTextGameObject = ((Component)_nameTmpTextTransform).gameObject;
			_nameTmpText = _nameTmpTextGameObject.GetComponent<TextMeshProUGUI>();
			_containerTransform = ((Component)this).transform.Find("C_Container");
			_containerGameObject = ((Component)_containerTransform).gameObject;
			_kickBanDropdownTransform = _containerTransform.Find("D_KickBan");
			_kickBanTmpDropdownGameObject = ((Component)_kickBanDropdownTransform).gameObject;
			_kickBanTmpDropdown = _kickBanTmpDropdownGameObject.GetComponent<TMP_Dropdown>();
			_hostImageTransform = _containerTransform.Find("I_Host");
			_hostImageGameObject = ((Component)_hostImageTransform).gameObject;
			_hostImage = _hostImageGameObject.GetComponent<Image>();
		}

		private void Start()
		{
			_onKickBanDropdownValueChangedAction = UnityAction<int>.op_Implicit((Action<int>)OnKickBanTmpDropdownValueChanged);
			((UnityEvent<int>)(object)_kickBanTmpDropdown.onValueChanged).AddListener(_onKickBanDropdownValueChangedAction);
			SteamNetworkLobby lobby = SteamManager.Instance.Lobby;
			if (lobby != null)
			{
				lobby.OnUpdateMemberData = (SteamNetworkLobby.OnUpdateMemberDataDelegate)Delegate.Combine(lobby.OnUpdateMemberData, new SteamNetworkLobby.OnUpdateMemberDataDelegate(OnUpdateMemberData));
			}
			SteamAvatarImageCache instance = SteamAvatarImageCache.Instance;
			if ((Object)(object)instance != (Object)null)
			{
				instance.OnAvatarImageTextureLoaded += OnAvatarImageTextureLoaded;
			}
		}

		private void OnKickBanTmpDropdownValueChanged(int value)
		{
			switch (value)
			{
			case 1:
				SteamNetworkLobby.Instance?.MemberKick(_steamNetworkLobbyMember.UserId);
				_kickBanTmpDropdown.SetValue(0, false);
				break;
			case 2:
				SteamNetworkLobby.Instance?.MemberBan(_steamNetworkLobbyMember.UserId);
				_kickBanTmpDropdown.SetValue(0, false);
				break;
			case 0:
				break;
			}
		}

		private void OnUpdateMemberData(SteamNetworkLobby steamNetworkLobby, SteamNetworkLobbyMember member)
		{
			if (_steamNetworkLobbyMember == member)
			{
				TrySetAvatarImage();
				TrySetReadyStatus();
				TrySetPersonaName();
				TrySetHostAndKickBanOptions();
			}
		}

		private void OnAvatarImageTextureLoaded(CSteamID steamUserId, SteamAvatarImageSize steamAvatarImageSize, Texture2D avatarImageTexture)
		{
			if (_steamNetworkLobbyMember != null && !(_steamNetworkLobbyMember.UserId != steamUserId) && _networkLobbyUiType == NetworkLobbyUiType.NetworkLobby)
			{
				_avatarImage.texture = (Texture)(object)avatarImageTexture;
			}
		}

		[HideFromIl2Cpp]
		internal void SetSteamNetworkLobbyMember(SteamNetworkLobbyMember steamNetworkLobbyMember, NetworkLobbyUiType networkLobbyUiType)
		{
			if (steamNetworkLobbyMember != null)
			{
				_steamNetworkLobbyMember = steamNetworkLobbyMember;
				if (networkLobbyUiType != NetworkLobbyUiType.None)
				{
					_networkLobbyUiType = networkLobbyUiType;
					OnSteamNetworkLobbyMemberSet();
				}
			}
		}

		private void OnSteamNetworkLobbyMemberSet()
		{
			CoroutineRunner.Start(DelayedOnSteamNetworkLobbyMemberSet());
		}

		private IEnumerator DelayedOnSteamNetworkLobbyMemberSet()
		{
			yield return (object)new WaitForEndOfFrame();
			if (_steamNetworkLobbyMember != null)
			{
				TrySetAvatarImage();
				TrySetReadyStatus();
				TrySetPersonaName();
				TrySetHostAndKickBanOptions();
			}
		}

		private void TrySetAvatarImage()
		{
			//IL_006f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0074: Unknown result type (might be due to invalid IL or missing references)
			//IL_0076: Unknown result type (might be due to invalid IL or missing references)
			if ((Object)(object)_avatarImage == (Object)null)
			{
				return;
			}
			if (_networkLobbyUiType == NetworkLobbyUiType.NetworkLobby)
			{
				if (SteamAvatarImageCache.Instance.TryGetAvatarImageTexture(_steamNetworkLobbyMember.UserId, SteamAvatarImageSize.Medium, out var avatarImageTexture) && (Object)(object)_avatarImage.texture != (Object)(object)avatarImageTexture)
				{
					_avatarImage.texture = (Texture)(object)avatarImageTexture;
				}
			}
			else
			{
				if (_networkLobbyUiType != NetworkLobbyUiType.NetworkGameLobby)
				{
					return;
				}
				DataManager instance = DataManager.Instance;
				if (!((Object)(object)instance != (Object)null))
				{
					return;
				}
				ECharacter character = _steamNetworkLobbyMember.Character;
				CharacterData characterData = instance.GetCharacterData(character);
				if ((Object)(object)characterData != (Object)null)
				{
					Texture icon = characterData.icon;
					if ((Object)(object)_avatarImage.texture != (Object)(object)icon)
					{
						_avatarImage.texture = icon;
					}
				}
			}
		}

		private void TrySetReadyStatus()
		{
			if ((Object)(object)_readyImage == (Object)null || (Object)(object)_notReadyImage == (Object)null)
			{
				return;
			}
			if (_networkLobbyUiType == NetworkLobbyUiType.NetworkGameLobby)
			{
				if (_steamNetworkLobbyMember.IsReady)
				{
					_readyImageGameObject.SetActive(true);
					_notReadyImageGameObject.SetActive(false);
				}
				else
				{
					_readyImageGameObject.SetActive(false);
					_notReadyImageGameObject.SetActive(true);
				}
			}
			else if (_networkLobbyUiType == NetworkLobbyUiType.NetworkLobby)
			{
				_readyImageGameObject.SetActive(false);
				_notReadyImageGameObject.SetActive(false);
			}
		}

		private void TrySetPersonaName()
		{
			if (!((Object)(object)_nameTmpText == (Object)null))
			{
				string orRequestName = SteamPersonaNameCache.GetOrRequestName(_steamNetworkLobbyMember.UserId);
				if (((TMP_Text)_nameTmpText).text != orRequestName)
				{
					((TMP_Text)_nameTmpText).text = orRequestName;
				}
			}
		}

		private void TrySetHostAndKickBanOptions()
		{
			if (!((Object)(object)_kickBanTmpDropdownGameObject == (Object)null) && !((Object)(object)_hostImageGameObject == (Object)null))
			{
				_kickBanTmpDropdownGameObject.SetActive(false);
				_hostImageGameObject.SetActive(false);
				if (SteamManager.Instance.Lobby.OwnedByUs() && _steamNetworkLobbyMember.UserId != SteamManager.Instance.CurrentUserId)
				{
					_kickBanTmpDropdownGameObject.SetActive(true);
				}
				if (_steamNetworkLobbyMember.UserId == SteamManager.Instance.Lobby.LobbyOwnerUserId)
				{
					_hostImageGameObject.SetActive(true);
				}
			}
		}

		private void OnEnable()
		{
		}

		private void OnDisable()
		{
		}

		private void OnDestroy()
		{
			_steamNetworkLobbyMember = null;
			try
			{
				TMP_Dropdown kickBanTmpDropdown = _kickBanTmpDropdown;
				if (kickBanTmpDropdown != null)
				{
					((UnityEvent<int>)(object)kickBanTmpDropdown.onValueChanged)?.RemoveListener(_onKickBanDropdownValueChangedAction);
				}
			}
			catch
			{
			}
			SteamNetworkLobby lobby = SteamManager.Instance.Lobby;
			if (lobby != null)
			{
				lobby.OnUpdateMemberData = (SteamNetworkLobby.OnUpdateMemberDataDelegate)Delegate.Remove(lobby.OnUpdateMemberData, new SteamNetworkLobby.OnUpdateMemberDataDelegate(OnUpdateMemberData));
			}
			SteamAvatarImageCache instance = SteamAvatarImageCache.Instance;
			if ((Object)(object)instance != (Object)null)
			{
				instance.OnAvatarImageTextureLoaded -= OnAvatarImageTextureLoaded;
			}
		}
	}
	internal enum NetworkLobbyUiType
	{
		None = -1,
		NetworkLobby,
		NetworkGameLobby
	}
	[RegisterTypeInIl2Cpp]
	public sealed class NetworkLobbyUi : MonoBehaviour
	{
		private Transform _networkLobbyWindowTransform;

		private GameObject _networkLobbyWindowGameObject;

		private NetworkLobbyWindowUi _networkLobbyWindowUi;

		private SteamNetworkLobby _steamNetworkLobby;

		internal static NetworkLobbyUi Instance { get; private set; }

		public NetworkLobbyUi(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public NetworkLobbyUi()
			: base(ClassInjector.DerivedConstructorPointer<NetworkLobbyUi>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			if ((Object)(object)Instance != (Object)null)
			{
				Object.DestroyImmediate((Object)(object)this);
				return;
			}
			_networkLobbyWindowTransform = ((Component)this).transform.Find("W_NetworkLobby");
			_networkLobbyWindowGameObject = ((Component)_networkLobbyWindowTransform).gameObject;
			_networkLobbyWindowUi = _networkLobbyWindowGameObject.AddComponent<NetworkLobbyWindowUi>();
			Instance = this;
		}

		private void Start()
		{
		}

		internal void OnMultiplayerButtonClick()
		{
			GoToNetworkLobby();
		}

		internal void GoToNetworkLobby()
		{
			MainMenu mainMenu = CustomUiManager.MainMenu;
			MenuCamera menuCamera = mainMenu.menuCamera;
			if (menuCamera != null)
			{
				menuCamera.GoToCharacters();
			}
			if ((Object)(object)mainMenu.currentTab != (Object)(object)_networkLobbyWindowGameObject)
			{
				GameObject currentTab = mainMenu.currentTab;
				if (currentTab != null)
				{
					currentTab.SetActive(false);
				}
				_networkLobbyWindowGameObject.SetActive(true);
				mainMenu.currentTab = _networkLobbyWindowGameObject;
			}
		}

		private IEnumerator DelayedGoToNetworkLobby()
		{
			yield return (object)new WaitForEndOfFrame();
		}
	}
	[RegisterTypeInIl2Cpp]
	public sealed class NetworkLobbyWindowUi : MonoBehaviour
	{
		private Window _networkLobbyWindow;

		private Transform _networkLobbyContainerTransform;

		private Transform _networkGameButtonsContainerTransform;

		private GameObject _networkGameButtonsContainerGameObject;

		private NetworkGameButtonsUi _networkGameButtonsUi;

		private Transform _networkLobbyHeaderTextTransform;

		private GameObject _networkLobbyHeaderTextGameObject;

		private TextMeshProUGUI _networkLobbyHeaderTextTmp;

		private Transform _networkLobbyScrollViewViewportContentTransform;

		private GameObject _networkLobbyMemberPrefab;

		private Transform _networkLobbyInviteMemberContainerTransform;

		private GameObject _networkLobbyInviteMemberContainerGameObject;

		private NetworkLobbyInviteMemberUi _networkLobbyInviteMemberUi;

		private Transform _networkLobbyButtonsContainerTransform;

		private GameObject _networkLobbyButtonsContainerGameObject;

		private Transform _networkGameActionButtonsContainerTransform;

		private GameObject _networkGameActionButtonsContainerGameObject;

		private NetworkGameActionButtonsUi _networkGameActionButtonsUi;

		private SteamNetworkLobby _steamNetworkLobby;

		private ConcurrentDictionary<SteamNetworkLobbyMember, NetworkLobbyMemberUi> _lobbyMemberUis = new ConcurrentDictionary<SteamNetworkLobbyMember, NetworkLobbyMemberUi>();

		internal static NetworkLobbyWindowUi Instance { get; private set; }

		internal NetworkLobbyUiType NetworkLobbyUiType { get; private set; }

		public NetworkLobbyWindowUi(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public NetworkLobbyWindowUi()
			: base(ClassInjector.DerivedConstructorPointer<NetworkLobbyWindowUi>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			if ((Object)(object)Instance != (Object)null)
			{
				Object.DestroyImmediate((Object)(object)this);
				return;
			}
			SubscribeToCallbacksAndCallResults();
			_networkLobbyContainerTransform = ((Component)this).transform.Find("C_NetworkLobby");
			Transform val = _networkLobbyContainerTransform.Find("P_NetworkLobby_Header");
			_networkLobbyHeaderTextTransform = val.Find("TMP_Text");
			_networkLobbyHeaderTextGameObject = ((Component)_networkLobbyHeaderTextTransform).gameObject;
			_networkLobbyHeaderTextTmp = _networkLobbyHeaderTextGameObject.GetComponent<TextMeshProUGUI>();
			Transform val2 = _networkLobbyContainerTransform.Find("SV_NetworkLobby").Find("Viewport");
			_networkLobbyScrollViewViewportContentTransform = val2.Find("Content");
			Transform val3 = _networkLobbyScrollViewViewportContentTransform.Find("C_NetworkLobbyMember");
			_networkLobbyMemberPrefab = ((Component)val3).gameObject;
			_networkLobbyMemberPrefab.AddComponent<NetworkLobbyMemberUi>();
			_networkLobbyInviteMemberContainerTransform = _networkLobbyScrollViewViewportContentTransform.Find("C_Invite");
			_networkLobbyInviteMemberContainerGameObject = ((Component)_networkLobbyInviteMemberContainerTransform).gameObject;
			_networkLobbyInviteMemberUi = _networkLobbyInviteMemberContainerGameObject.AddComponent<NetworkLobbyInviteMemberUi>();
			_networkLobbyButtonsContainerTransform = _networkLobbyContainerTransform.Find("C_NetworkLobbyButtons");
			_networkLobbyButtonsContainerGameObject = ((Component)_networkLobbyButtonsContainerTransform).gameObject;
			_networkLobbyButtonsContainerGameObject.AddComponent<NetworkLobbyButtonsUi>();
			_networkGameButtonsContainerTransform = ((Component)this).transform.Find("C_NetworkGameButtons");
			_networkGameButtonsContainerGameObject = ((Component)_networkGameButtonsContainerTransform).gameObject;
			_networkGameButtonsUi = _networkGameButtonsContainerGameObject.AddComponent<NetworkGameButtonsUi>();
			_networkGameActionButtonsContainerTransform = ((Component)this).transform.Find("C_NetworkGameActionButtons");
			_networkGameActionButtonsContainerGameObject = ((Component)_networkGameActionButtonsContainerTransform).gameObject;
			_networkGameActionButtonsUi = _networkGameActionButtonsContainerGameObject.AddComponent<NetworkGameActionButtonsUi>();
			SetNetworkLobbyUiType(NetworkLobbyUiType.NetworkLobby);
			Instance = this;
		}

		private void SubscribeToCallbacksAndCallResults()
		{
			SteamNetworkLobbyManager.OnLobbyEntered = (OnLobbyEnteredDelegate)Delegate.Combine(SteamNetworkLobbyManager.OnLobbyEntered, new OnLobbyEnteredDelegate(OnLobbyEntered));
			SteamNetworkLobbyManager.OnLobbyLeft = (OnLobbyLeftDelegate)Delegate.Combine(SteamNetworkLobbyManager.OnLobbyLeft, new OnLobbyLeftDelegate(OnLobbyLeft));
		}

		private void OnLobbyEntered(SteamNetworkLobby steamNetworkLobby)
		{
			_steamNetworkLobby = steamNetworkLobby;
			SteamNetworkLobby steamNetworkLobby2 = _steamNetworkLobby;
			steamNetworkLobby2.OnMemberAdded = (SteamNetworkLobby.OnMemberAddedDelegate)Delegate.Combine(steamNetworkLobby2.OnMemberAdded, new SteamNetworkLobby.OnMemberAddedDelegate(OnMemberAdded));
			SteamNetworkLobby steamNetworkLobby3 = _steamNetworkLobby;
			steamNetworkLobby3.OnMemberRemoved = (SteamNetworkLobby.OnMemberRemovedDelegate)Delegate.Combine(steamNetworkLobby3.OnMemberRemoved, new SteamNetworkLobby.OnMemberRemovedDelegate(OnMemberRemoved));
			SteamNetworkLobby steamNetworkLobby4 = _steamNetworkLobby;
			steamNetworkLobby4.OnUpdateLobbyData = (SteamNetworkLobby.OnUpdateLobbyDataDelegate)Delegate.Combine(steamNetworkLobby4.OnUpdateLobbyData, new SteamNetworkLobby.OnUpdateLobbyDataDelegate(OnUpdateLobbyData));
			NetworkLobbyUi.Instance?.GoToNetworkLobby();
			HideGameActionButtons();
			Refresh();
		}

		private void OnMemberAdded(SteamNetworkLobby steamNetworkLobby, SteamNetworkLobbyMember member)
		{
			if (((Component)this).gameObject.activeInHierarchy)
			{
				Refresh();
			}
		}

		private void OnMemberRemoved(SteamNetworkLobby steamNetworkLobby, SteamNetworkLobbyMember member)
		{
			if (((Component)this).gameObject.activeInHierarchy)
			{
				Refresh();
			}
		}

		private void OnUpdateLobbyData(SteamNetworkLobby steamNetworkLobby)
		{
			if (((Component)this).gameObject.activeInHierarchy)
			{
				Refresh();
			}
		}

		private void OnLobbyLeft(SteamNetworkLobby steamNetworkLobby)
		{
			if (!((Component)this).gameObject.activeInHierarchy)
			{
				return;
			}
			if (_steamNetworkLobby == steamNetworkLobby)
			{
				SteamNetworkLobby steamNetworkLobby2 = _steamNetworkLobby;
				if (steamNetworkLobby2 != null)
				{
					steamNetworkLobby2.OnMemberAdded = (SteamNetworkLobby.OnMemberAddedDelegate)Delegate.Remove(steamNetworkLobby2.OnMemberAdded, new SteamNetworkLobby.OnMemberAddedDelegate(OnMemberAdded));
				}
				SteamNetworkLobby steamNetworkLobby3 = _steamNetworkLobby;
				if (steamNetworkLobby3 != null)
				{
					steamNetworkLobby3.OnMemberRemoved = (SteamNetworkLobby.OnMemberRemovedDelegate)Delegate.Remove(steamNetworkLobby3.OnMemberRemoved, new SteamNetworkLobby.OnMemberRemovedDelegate(OnMemberRemoved));
				}
				SteamNetworkLobby steamNetworkLobby4 = _steamNetworkLobby;
				if (steamNetworkLobby4 != null)
				{
					steamNetworkLobby4.OnUpdateLobbyData = (SteamNetworkLobby.OnUpdateLobbyDataDelegate)Delegate.Remove(steamNetworkLobby4.OnUpdateLobbyData, new SteamNetworkLobby.OnUpdateLobbyDataDelegate(OnUpdateLobbyData));
				}
			}
			CoroutineRunner.Start(DelayedOnLobbyLeft());
		}

		private IEnumerator DelayedOnLobbyLeft()
		{
			for (int i = 0; i < 10; i++)
			{
				yield return (object)new WaitForEndOfFrame();
			}
			HideGameActionButtons();
			Refresh();
		}

		private void Refresh()
		{
			if (!((Component)this).gameObject.activeInHierarchy)
			{
				return;
			}
			if (_networkLobbyScrollViewViewportContentTransform.childCount > 2)
			{
				for (int num = _networkLobbyScrollViewViewportContentTransform.childCount - 1; num >= 0; num--)
				{
					GameObject gameObject = ((Component)_networkLobbyScrollViewViewportContentTransform.GetChild(num)).gameObject;
					if (!((Object)(object)gameObject == (Object)(object)_networkLobbyInviteMemberContainerGameObject) && !((Object)(object)gameObject == (Object)(object)_networkLobbyMemberPrefab))
					{
						Object.DestroyImmediate((Object)(object)gameObject);
					}
				}
			}
			if (_steamNetworkLobby == null)
			{
				return;
			}
			if (!string.IsNullOrWhiteSpace(_steamNetworkLobby.Name))
			{
				((TMP_Text)_networkLobbyHeaderTextTmp).text = _steamNetworkLobby.Name;
			}
			if (_steamNetworkLobby.Members.Count > 0)
			{
				_lobbyMemberUis.Clear();
				for (int i = 0; i < _steamNetworkLobby.Members.Count; i++)
				{
					SteamNetworkLobbyMember steamNetworkLobbyMember = _steamNetworkLobby.Members[i];
					GameObject val = Object.Instantiate<GameObject>(_networkLobbyMemberPrefab, _networkLobbyScrollViewViewportContentTransform);
					val.SetActive(true);
					NetworkLobbyMemberUi component = val.GetComponent<NetworkLobbyMemberUi>();
					component.SetSteamNetworkLobbyMember(steamNetworkLobbyMember, NetworkLobbyUiType);
					if (!_lobbyMemberUis.TryAdd(steamNetworkLobbyMember, component))
					{
						ModLogger.Error($"Failed to add lobby member UI for {SteamPersonaNameCache.GetOrRequestName(steamNetworkLobbyMember.UserId)} ({steamNetworkLobbyMember.UserId})");
					}
					if (steamNetworkLobbyMember.UserId == SteamNetworkLobby.Instance.LobbyOwnerUserId)
					{
						val.transform.SetAsFirstSibling();
					}
				}
			}
			if (_steamNetworkLobby.Members.Count >= _steamNetworkLobby.MaxMembers)
			{
				_networkLobbyInviteMemberContainerGameObject.SetActive(false);
			}
			else
			{
				_networkLobbyInviteMemberContainerTransform.SetAsLastSibling();
				_networkLobbyInviteMemberContainerGameObject.SetActive(true);
			}
			NetworkLobbyUiType = _steamNetworkLobby.NetworkLobbyUiType;
			if (_steamNetworkLobby.NetworkLobbyUiType == NetworkLobbyUiType.NetworkLobby)
			{
				HideGameActionButtons();
			}
			else if (_steamNetworkLobby.NetworkLobbyUiType == NetworkLobbyUiType.NetworkGameLobby)
			{
				ShowGameActionButtons();
			}
			_networkLobbyWindow.FindAllButtonsInWindow();
			UiUtility.RebuildUi(((Component)this).transform);
		}

		private void Start()
		{
			_networkLobbyWindow = ((Component)this).gameObject.AddComponent<Window>();
			_networkGameButtonsUi.ParentWindow = _networkLobbyWindow;
			_networkGameActionButtonsUi.ParentWindow = _networkLobbyWindow;
			_networkLobbyInviteMemberUi.ParentWindow = _networkLobbyWindow;
			CoroutineRunner.Start(DelayedStart());
		}

		private IEnumerator DelayedStart()
		{
			yield return (object)new WaitForEndOfFrame();
			if (!((Object)(object)_networkLobbyWindow == (Object)null))
			{
				_networkLobbyWindow.FindAllButtonsInWindow();
				UiUtility.RebuildUi(((Component)this).transform);
			}
		}

		private void OnEnable()
		{
			CoroutineRunner.Start(DelayedOnEnable());
		}

		private IEnumerator DelayedOnEnable()
		{
			yield return (object)new WaitForEndOfFrame();
			if (SteamManager.Instance.Lobby == null && SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joining)
			{
				SteamNetworkLobbyManager.CreateLobby(SteamNetworkLobbyType.Private);
			}
			Refresh();
		}

		private void OnDisable()
		{
			CoroutineRunner.Start(DelayedOnDisable());
		}

		private IEnumerator DelayedOnDisable()
		{
			yield return (object)new WaitForEndOfFrame();
		}

		internal void SetNetworkLobbyUiType(NetworkLobbyUiType networkLobbyUiType)
		{
			NetworkLobbyUiType = networkLobbyUiType;
		}

		internal void ShowGameActionButtons()
		{
			_networkGameButtonsContainerGameObject.SetActive(false);
			_networkGameActionButtonsContainerGameObject.SetActive(true);
		}

		internal void HideGameActionButtons()
		{
			_networkGameActionButtonsContainerGameObject.SetActive(false);
			_networkGameButtonsContainerGameObject.SetActive(true);
		}

		private void OnDestroy()
		{
			UnsubscribeFromCallbacksAndCallResults();
		}

		private void UnsubscribeFromCallbacksAndCallResults()
		{
			SteamNetworkLobbyManager.OnLobbyEntered = (OnLobbyEnteredDelegate)Delegate.Remove(SteamNetworkLobbyManager.OnLobbyEntered, new OnLobbyEnteredDelegate(OnLobbyEntered));
			SteamNetworkLobbyManager.OnLobbyLeft = (OnLobbyLeftDelegate)Delegate.Remove(SteamNetworkLobbyManager.OnLobbyLeft, new OnLobbyLeftDelegate(OnLobbyLeft));
			SteamNetworkLobby steamNetworkLobby = _steamNetworkLobby;
			if (steamNetworkLobby != null)
			{
				steamNetworkLobby.OnMemberAdded = (SteamNetworkLobby.OnMemberAddedDelegate)Delegate.Remove(steamNetworkLobby.OnMemberAdded, new SteamNetworkLobby.OnMemberAddedDelegate(OnMemberAdded));
			}
			SteamNetworkLobby steamNetworkLobby2 = _steamNetworkLobby;
			if (steamNetworkLobby2 != null)
			{
				steamNetworkLobby2.OnMemberRemoved = (SteamNetworkLobby.OnMemberRemovedDelegate)Delegate.Remove(steamNetworkLobby2.OnMemberRemoved, new SteamNetworkLobby.OnMemberRemovedDelegate(OnMemberRemoved));
			}
			SteamNetworkLobby steamNetworkLobby3 = _steamNetworkLobby;
			if (steamNetworkLobby3 != null)
			{
				steamNetworkLobby3.OnUpdateLobbyData = (SteamNetworkLobby.OnUpdateLobbyDataDelegate)Delegate.Remove(steamNetworkLobby3.OnUpdateLobbyData, new SteamNetworkLobby.OnUpdateLobbyDataDelegate(OnUpdateLobbyData));
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.UI.Chat
{
	[RegisterTypeInIl2Cpp]
	public class ChatWindowUi : MonoBehaviour
	{
		private struct ChatEntry
		{
			public ulong SteamId;

			public string PlayerName;

			public string Message;

			public GameObject UIElement;
		}

		private const int MaxMessages = 50;

		private const float FadeDelay = 8f;

		private const float FadeDuration = 1f;

		private const float InputHeight = 40f;

		private const float MessageHeight = 24f;

		private const float WindowWidth = 400f;

		private const float WindowHeight = 200f;

		private const float Padding = 10f;

		private GameObject _chatContainer;

		private GameObject _messagesPanel;

		private GameObject _inputPanel;

		private ScrollRect _scrollRect;

		private RectTransform _contentTransform;

		private TMP_InputField _inputField;

		private CanvasGroup _messagesCanvasGroup;

		private CanvasGroup _inputCanvasGroup;

		private readonly List<ChatEntry> _messages = new List<ChatEntry>();

		private float _lastMessageTime;

		private bool _isInputActive;

		private bool _isFading;

		private Coroutine _fadeCoroutine;

		public static ChatWindowUi Instance { get; private set; }

		public ChatWindowUi(IntPtr ptr)
			: base(ptr)
		{
		}

		public ChatWindowUi()
			: base(ClassInjector.DerivedConstructorPointer<ChatWindowUi>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			if ((Object)(object)Instance != (Object)null)
			{
				Object.Destroy((Object)(object)((Component)this).gameObject);
				return;
			}
			Instance = this;
			Object.DontDestroyOnLoad((Object)(object)((Component)this).gameObject);
			CreateUI();
		}

		private void CreateUI()
		{
			//IL_0006: Unknown result type (might be due to invalid IL or missing references)
			//IL_0010: Expected O, but got Unknown
			//IL_003d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0052: Unknown result type (might be due to invalid IL or missing references)
			//IL_0067: Unknown result type (might be due to invalid IL or missing references)
			//IL_007c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0090: Unknown result type (might be due to invalid IL or missing references)
			_chatContainer = new GameObject("ChatContainer");
			_chatContainer.transform.SetParent(((Component)this).transform, false);
			RectTransform obj = _chatContainer.AddComponent<RectTransform>();
			obj.anchorMin = new Vector2(0f, 0f);
			obj.anchorMax = new Vector2(0f, 0f);
			obj.pivot = new Vector2(0f, 0f);
			obj.anchoredPosition = new Vector2(10f, 70f);
			obj.sizeDelta = new Vector2(400f, 250f);
			CreateMessagesPanel();
			CreateInputPanel();
			_inputCanvasGroup.alpha = 0f;
			_inputCanvasGroup.interactable = false;
			_inputCanvasGroup.blocksRaycasts = false;
			_messagesCanvasGroup.alpha = 0f;
		}

		private void CreateMessagesPanel()
		{
			//IL_0006: Unknown result type (might be due to invalid IL or missing references)
			//IL_0010: Expected O, but got Unknown
			//IL_0042: Unknown result type (might be due to invalid IL or missing references)
			//IL_0057: Unknown result type (might be due to invalid IL or missing references)
			//IL_006c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0081: Unknown result type (might be due to invalid IL or missing references)
			//IL_0095: Unknown result type (might be due to invalid IL or missing references)
			//IL_00be: Unknown result type (might be due to invalid IL or missing references)
			//IL_012f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0135: Expected O, but got Unknown
			//IL_0168: Unknown result type (might be due to invalid IL or missing references)
			//IL_0182: Unknown result type (might be due to invalid IL or missing references)
			//IL_019c: Unknown result type (might be due to invalid IL or missing references)
			//IL_01ac: Unknown result type (might be due to invalid IL or missing references)
			//IL_01c6: Unknown result type (might be due to invalid IL or missing references)
			//IL_0204: Unknown result type (might be due to invalid IL or missing references)
			//IL_020a: Expected O, but got Unknown
			_messagesPanel = new GameObject("MessagesPanel");
			_messagesPanel.transform.SetParent(_chatContainer.transform, false);
			RectTransform obj = _messagesPanel.AddComponent<RectTransform>();
			obj.anchorMin = new Vector2(0f, 1f);
			obj.anchorMax = new Vector2(1f, 1f);
			obj.pivot = new Vector2(0f, 1f);
			obj.anchoredPosition = new Vector2(0f, 0f);
			obj.sizeDelta = new Vector2(0f, 200f);
			((Graphic)_messagesPanel.AddComponent<Image>()).color = new Color(0.05f, 0.05f, 0.05f, 0.7f);
			_messagesCanvasGroup = _messagesPanel.AddComponent<CanvasGroup>();
			_messagesPanel.AddComponent<RectMask2D>();
			_scrollRect = _messagesPanel.AddComponent<ScrollRect>();
			_scrollRect.horizontal = false;
			_scrollRect.vertical = true;
			_scrollRect.movementType = (MovementType)2;
			_scrollRect.scrollSensitivity = 20f;
			GameObject val = new GameObject("Content");
			val.transform.SetParent(_messagesPanel.transform, false);
			_contentTransform = val.AddComponent<RectTransform>();
			_contentTransform.anchorMin = new Vector2(0f, 1f);
			_contentTransform.anchorMax = new Vector2(1f, 1f);
			_contentTransform.pivot = new Vector2(0f, 1f);
			_contentTransform.anchoredPosition = Vector2.zero;
			_contentTransform.sizeDelta = new Vector2(-20f, 0f);
			VerticalLayoutGroup obj2 = val.AddComponent<VerticalLayoutGroup>();
			((LayoutGroup)obj2).childAlignment = (TextAnchor)6;
			((HorizontalOrVerticalLayoutGroup)obj2).childControlHeight = true;
			((HorizontalOrVerticalLayoutGroup)obj2).childControlWidth = true;
			((HorizontalOrVerticalLayoutGroup)obj2).childForceExpandHeight = false;
			((HorizontalOrVerticalLayoutGroup)obj2).childForceExpandWidth = true;
			((HorizontalOrVerticalLayoutGroup)obj2).spacing = 2f;
			RectOffset val2 = new RectOffset();
			val2.left = 10;
			val2.right = 10;
			val2.top = 10;
			val2.bottom = 10;
			((LayoutGroup)obj2).padding = val2;
			ContentSizeFitter obj3 = val.AddComponent<ContentSizeFitter>();
			obj3.verticalFit = (FitMode)2;
			obj3.horizontalFit = (FitMode)0;
			_scrollRect.content = _contentTransform;
		}

		private void CreateInputPanel()
		{
			//IL_0006: Unknown result type (might be due to invalid IL or missing references)
			//IL_0010: Expected O, but got Unknown
			//IL_0042: Unknown result type (might be due to invalid IL or missing references)
			//IL_0057: Unknown result type (might be due to invalid IL or missing references)
			//IL_006c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0081: Unknown result type (might be due to invalid IL or missing references)
			//IL_0095: Unknown result type (might be due to invalid IL or missing references)
			//IL_00be: Unknown result type (might be due to invalid IL or missing references)
			//IL_00de: Unknown result type (might be due to invalid IL or missing references)
			//IL_00e4: Expected O, but got Unknown
			//IL_0102: Unknown result type (might be due to invalid IL or missing references)
			//IL_010d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0122: Unknown result type (might be due to invalid IL or missing references)
			//IL_0136: Unknown result type (might be due to invalid IL or missing references)
			//IL_0151: Unknown result type (might be due to invalid IL or missing references)
			//IL_0157: Expected O, but got Unknown
			//IL_0171: Unknown result type (might be due to invalid IL or missing references)
			//IL_017c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0187: Unknown result type (might be due to invalid IL or missing references)
			//IL_0192: Unknown result type (might be due to invalid IL or missing references)
			//IL_01a8: Unknown result type (might be due to invalid IL or missing references)
			//IL_01ad: Unknown result type (might be due to invalid IL or missing references)
			//IL_01bf: Unknown result type (might be due to invalid IL or missing references)
			//IL_01c6: Unknown result type (might be due to invalid IL or missing references)
			//IL_01d1: Unknown result type (might be due to invalid IL or missing references)
			//IL_01e6: Unknown result type (might be due to invalid IL or missing references)
			//IL_01fa: Unknown result type (might be due to invalid IL or missing references)
			//IL_0235: Unknown result type (might be due to invalid IL or missing references)
			//IL_024f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0254: Unknown result type (might be due to invalid IL or missing references)
			//IL_0266: Unknown result type (might be due to invalid IL or missing references)
			//IL_026d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0278: Unknown result type (might be due to invalid IL or missing references)
			//IL_028d: Unknown result type (might be due to invalid IL or missing references)
			//IL_02a1: Unknown result type (might be due to invalid IL or missing references)
			//IL_02c0: Unknown result type (might be due to invalid IL or missing references)
			_inputPanel = new GameObject("InputPanel");
			_inputPanel.transform.SetParent(_chatContainer.transform, false);
			RectTransform obj = _inputPanel.AddComponent<RectTransform>();
			obj.anchorMin = new Vector2(0f, 1f);
			obj.anchorMax = new Vector2(1f, 1f);
			obj.pivot = new Vector2(0f, 1f);
			obj.anchoredPosition = new Vector2(0f, -205f);
			obj.sizeDelta = new Vector2(0f, 40f);
			((Graphic)_inputPanel.AddComponent<Image>()).color = new Color(0.1f, 0.1f, 0.1f, 0.9f);
			_inputCanvasGroup = _inputPanel.AddComponent<CanvasGroup>();
			GameObject val = new GameObject("InputContainer");
			val.transform.SetParent(_inputPanel.transform, false);
			RectTransform obj2 = val.AddComponent<RectTransform>();
			obj2.anchorMin = Vector2.zero;
			obj2.anchorMax = Vector2.one;
			obj2.offsetMin = new Vector2(10f, 5f);
			obj2.offsetMax = new Vector2(-10f, -5f);
			_inputField = val.AddComponent<TMP_InputField>();
			GameObject val2 = new GameObject("TextArea");
			val2.transform.SetParent(val.transform, false);
			RectTransform val3 = val2.AddComponent<RectTransform>();
			val3.anchorMin = Vector2.zero;
			val3.anchorMax = Vector2.one;
			val3.offsetMin = Vector2.zero;
			val3.offsetMax = Vector2.zero;
			val2.AddComponent<RectMask2D>();
			GameObject val4 = new GameObject("Placeholder");
			val4.transform.SetParent(val2.transform, false);
			RectTransform obj3 = val4.AddComponent<RectTransform>();
			obj3.anchorMin = Vector2.zero;
			obj3.anchorMax = Vector2.one;
			obj3.offsetMin = new Vector2(5f, 0f);
			obj3.offsetMax = new Vector2(-5f, 0f);
			TextMeshProUGUI val5 = val4.AddComponent<TextMeshProUGUI>();
			((TMP_Text)val5).text = "Press Enter to chat...";
			((TMP_Text)val5).fontSize = 16f;
			((Graphic)val5).color = new Color(0.5f, 0.5f, 0.5f, 0.8f);
			((TMP_Text)val5).alignment = (TextAlignmentOptions)4097;
			GameObject val6 = new GameObject("Text");
			val6.transform.SetParent(val2.transform, false);
			RectTransform obj4 = val6.AddComponent<RectTransform>();
			obj4.anchorMin = Vector2.zero;
			obj4.anchorMax = Vector2.one;
			obj4.offsetMin = new Vector2(5f, 0f);
			obj4.offsetMax = new Vector2(-5f, 0f);
			TextMeshProUGUI val7 = val6.AddComponent<TextMeshProUGUI>();
			((TMP_Text)val7).fontSize = 16f;
			((Graphic)val7).color = Color.white;
			((TMP_Text)val7).alignment = (TextAlignmentOptions)4097;
			_inputField.textViewport = val3;
			_inputField.textComponent = (TMP_Text)(object)val7;
			_inputField.placeholder = (Graphic)(object)val5;
			_inputField.characterLimit = 200;
			_inputField.lineType = (LineType)0;
			((UnityEvent<string>)(object)_inputField.onSubmit).AddListener(UnityAction<string>.op_Implicit((Action<string>)OnSubmitMessage));
		}

		private void Update()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return;
			}
			if (Input.GetKeyDown((KeyCode)13) || Input.GetKeyDown((KeyCode)271))
			{
				if (!_isInputActive)
				{
					if (Time.time - _lastMessageTime > 0.1f)
					{
						OpenChat();
					}
				}
				else if (!_inputField.isFocused)
				{
					_inputField.ActivateInputField();
					((Selectable)_inputField).Select();
				}
			}
			else if (Input.GetKeyDown((KeyCode)27) && _isInputActive)
			{
				CloseChat();
			}
			if (!_isInputActive && !_isFading && _messages.Count > 0 && Time.time - _lastMessageTime > 8f && _messagesCanvasGroup.alpha > 0f)
			{
				_fadeCoroutine = CoroutineRunner.Start(FadeOut());
			}
		}

		private void OpenChat()
		{
			_isInputActive = true;
			_inputCanvasGroup.alpha = 1f;
			_inputCanvasGroup.interactable = true;
			_inputCanvasGroup.blocksRaycasts = true;
			_messagesCanvasGroup.alpha = 1f;
			if (_fadeCoroutine != null)
			{
				CoroutineRunner.Stop(_fadeCoroutine);
				_fadeCoroutine = null;
			}
			_isFading = false;
			_inputField.ActivateInputField();
			((Selectable)_inputField).Select();
		}

		private void CloseChat()
		{
			_isInputActive = false;
			_inputCanvasGroup.alpha = 0f;
			_inputCanvasGroup.interactable = false;
			_inputCanvasGroup.blocksRaycasts = false;
			_inputField.DeactivateInputField(false);
			_inputField.text = string.Empty;
			_lastMessageTime = Time.time;
		}

		private void OnSubmitMessage(string text)
		{
			if (string.IsNullOrWhiteSpace(text))
			{
				CloseChat();
				return;
			}
			ChatMessage chatMessage = new ChatMessage(text.Trim());
			ulong steamID = SteamManager.Instance.CurrentUserId.m_SteamID;
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				chatMessage.SenderSteamId = steamID;
				SteamNetworkServer.Instance?.BroadcastMessage(chatMessage);
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				SteamNetworkClient.Instance?.SendMessage(chatMessage);
			}
			AddMessage(steamID, text.Trim());
			_inputField.text = string.Empty;
			CloseChat();
		}

		public void AddMessage(ulong senderSteamId, string message)
		{
			//IL_0011: Unknown result type (might be due to invalid IL or missing references)
			//IL_0017: Expected O, but got Unknown
			//IL_0039: Unknown result type (might be due to invalid IL or missing references)
			//IL_006c: Unknown result type (might be due to invalid IL or missing references)
			string orRequestName = SteamPersonaNameCache.GetOrRequestName(new CSteamID(senderSteamId));
			GameObject val = new GameObject("ChatMessage");
			val.transform.SetParent((Transform)(object)_contentTransform, false);
			val.AddComponent<RectTransform>().sizeDelta = new Vector2(0f, 24f);
			TextMeshProUGUI obj = val.AddComponent<TextMeshProUGUI>();
			((TMP_Text)obj).text = "<color=#88CCFF>" + orRequestName + "</color>: " + message;
			((TMP_Text)obj).fontSize = 14f;
			((Graphic)obj).color = Color.white;
			((TMP_Text)obj).alignment = (TextAlignmentOptions)257;
			((TMP_Text)obj).enableWordWrapping = true;
			((TMP_Text)obj).overflowMode = (TextOverflowModes)3;
			ChatEntry item = new ChatEntry
			{
				SteamId = senderSteamId,
				PlayerName = orRequestName,
				Message = message,
				UIElement = val
			};
			_messages.Add(item);
			while (_messages.Count > 50)
			{
				ChatEntry chatEntry = _messages[0];
				_messages.RemoveAt(0);
				if (Object.op_Implicit((Object)(object)chatEntry.UIElement))
				{
					Object.Destroy((Object)(object)chatEntry.UIElement);
				}
			}
			_messagesCanvasGroup.alpha = 1f;
			_lastMessageTime = Time.time;
			if (_fadeCoroutine != null)
			{
				CoroutineRunner.Stop(_fadeCoroutine);
				_fadeCoroutine = null;
			}
			_isFading = false;
			CoroutineRunner.Start(ScrollToBottom());
		}

		private IEnumerator ScrollToBottom()
		{
			yield return null;
			_scrollRect.normalizedPosition = Vector2.zero;
		}

		private IEnumerator FadeOut()
		{
			_isFading = true;
			float elapsed = 0f;
			while (elapsed < 1f)
			{
				elapsed += Time.deltaTime;
				_messagesCanvasGroup.alpha = Mathf.Lerp(1f, 0f, elapsed / 1f);
				yield return null;
			}
			_messagesCanvasGroup.alpha = 0f;
			_isFading = false;
			_fadeCoroutine = null;
		}

		private void OnDestroy()
		{
			if ((Object)(object)Instance == (Object)(object)this)
			{
				Instance = null;
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.Steam
{
	[RegisterTypeInIl2Cpp]
	public class SteamAvatarImageCache : MonoBehaviour
	{
		internal delegate void OnAvatarImageSpriteLoadedDelegate(CSteamID steamUserId, SteamAvatarImageSize steamAvatarImageSize, Sprite avatarImageSprite);

		internal delegate void OnAvatarImageTextureLoadedDelegate(CSteamID steamUserId, SteamAvatarImageSize steamAvatarImageSize, Texture2D avatarImageTexture);

		private class AvatarImageTextureRequest
		{
			internal CSteamID UserId { get; private set; }

			internal SteamAvatarImageSize AvatarImageSize { get; private set; }

			internal int Width { get; private set; }

			internal int Height { get; private set; }

			internal byte[] RawImage { get; private set; }

			internal AvatarImageTextureRequest(CSteamID userId, SteamAvatarImageSize avatarImageSize, int width, int height, byte[] rawImage)
			{
				UserId = userId;
				AvatarImageSize = avatarImageSize;
				Width = width;
				Height = height;
				RawImage = rawImage;
			}
		}

		internal const int SmallAvatarWidthAndHeight = 32;

		internal const int MediumAvatarWidthAndHeight = 64;

		internal const int LargeAvatarWidthAndHeight = 184;

		private CSteamID _currentSteamUserId;

		private ConcurrentQueue<AvatarImageTextureRequest> _avatarImageTextureRequests;

		private ConcurrentDictionary<CSteamID, Texture2D> _smallAvatarImageTextures;

		private ConcurrentDictionary<CSteamID, Texture2D> _mediumAvatarImageTextures;

		private ConcurrentDictionary<CSteamID, Texture2D> _largeAvatarImageTextures;

		private ConcurrentDictionary<Texture2D, Sprite> _smallAvatarImageSprites;

		private ConcurrentDictionary<Texture2D, Sprite> _mediumAvatarImageSprites;

		private ConcurrentDictionary<Texture2D, Sprite> _largeAvatarImageSprites;

		internal static SteamAvatarImageCache Instance { get; private set; }

		internal event OnAvatarImageSpriteLoadedDelegate OnAvatarImageSpriteLoaded;

		internal event OnAvatarImageTextureLoadedDelegate OnAvatarImageTextureLoaded;

		public SteamAvatarImageCache(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public SteamAvatarImageCache()
			: base(ClassInjector.DerivedConstructorPointer<SteamAvatarImageCache>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			if (Instance != null)
			{
				Object.DestroyImmediate((Object)(object)Instance);
				return;
			}
			_currentSteamUserId = SteamUser.GetSteamID();
			_avatarImageTextureRequests = new ConcurrentQueue<AvatarImageTextureRequest>();
			_smallAvatarImageTextures = new ConcurrentDictionary<CSteamID, Texture2D>();
			_mediumAvatarImageTextures = new ConcurrentDictionary<CSteamID, Texture2D>();
			_largeAvatarImageTextures = new ConcurrentDictionary<CSteamID, Texture2D>();
			_smallAvatarImageSprites = new ConcurrentDictionary<Texture2D, Sprite>();
			_mediumAvatarImageSprites = new ConcurrentDictionary<Texture2D, Sprite>();
			_largeAvatarImageSprites = new ConcurrentDictionary<Texture2D, Sprite>();
			Instance = this;
		}

		private void Start()
		{
			SubscribeToCallbacksAndCallResults();
		}

		private void SubscribeToCallbacksAndCallResults()
		{
			SteamFriendsImpl.OnAvatarImageLoaded = (SteamFriendsImpl.AvatarImageLoadedCallbackDelegate)Delegate.Combine(SteamFriendsImpl.OnAvatarImageLoaded, new SteamFriendsImpl.AvatarImageLoadedCallbackDelegate(OnAvatarImageLoaded));
			SteamFriendsImpl.OnPersonaStateChangeAvatar = (SteamFriendsImpl.PersonaStateChangeAvatarCallbackDelegate)Delegate.Combine(SteamFriendsImpl.OnPersonaStateChangeAvatar, new SteamFriendsImpl.PersonaStateChangeAvatarCallbackDelegate(OnPersonaStateChangeAvatar));
		}

		private void OnAvatarImageLoaded(CSteamID steamUserId, int imageHandle, int width, int height)
		{
			SteamAvatarImageSize steamAvatarImageSize = GetAvatarImageSizeFromWidthAndHeight(width);
			Task.Run(() => GetRawAvatarImageBytesAndEnqueueForConversion(steamUserId, steamAvatarImageSize, imageHandle));
		}

		private SteamAvatarImageSize GetAvatarImageSizeFromWidthAndHeight(int widthAndHeight)
		{
			return widthAndHeight switch
			{
				32 => SteamAvatarImageSize.Small, 
				64 => SteamAvatarImageSize.Medium, 
				184 => SteamAvatarImageSize.Large, 
				_ => SteamAvatarImageSize.None, 
			};
		}

		private void OnPersonaStateChangeAvatar(CSteamID steamUserId)
		{
			RequestAvatarImageTexture(steamUserId, SteamAvatarImageSize.Small);
			RequestAvatarImageTexture(steamUserId, SteamAvatarImageSize.Medium);
			RequestAvatarImageTexture(steamUserId, SteamAvatarImageSize.Large);
		}

		private void RequestAvatarImageTexture(CSteamID steamUserId, SteamAvatarImageSize steamAvatarImageSize)
		{
			if (steamUserId != _currentSteamUserId && SteamFriends.RequestUserInformation(steamUserId, bRequireNameOnly: false))
			{
				return;
			}
			int avatarImageHandle = -2;
			switch (steamAvatarImageSize)
			{
			case SteamAvatarImageSize.None:
				return;
			case SteamAvatarImageSize.Small:
				avatarImageHandle = SteamFriends.GetSmallFriendAvatar(steamUserId);
				break;
			case SteamAvatarImageSize.Medium:
				avatarImageHandle = SteamFriends.GetMediumFriendAvatar(steamUserId);
				break;
			case SteamAvatarImageSize.Large:
				avatarImageHandle = SteamFriends.GetLargeFriendAvatar(steamUserId);
				break;
			}
			if (avatarImageHandle == -2 || avatarImageHandle == -1)
			{
				return;
			}
			if (avatarImageHandle == 0)
			{
				int widthOrHeightForAvatarImageSize = GetWidthOrHeightForAvatarImageSize(steamAvatarImageSize);
				byte[] rawImage = Array.Empty<byte>();
				AvatarImageTextureRequest item = new AvatarImageTextureRequest(steamUserId, steamAvatarImageSize, widthOrHeightForAvatarImageSize, widthOrHeightForAvatarImageSize, rawImage);
				_avatarImageTextureRequests.Enqueue(item);
			}
			else if (avatarImageHandle > 0)
			{
				Task.Run(() => GetRawAvatarImageBytesAndEnqueueForConversion(steamUserId, steamAvatarImageSize, avatarImageHandle));
			}
		}

		private int GetWidthOrHeightForAvatarImageSize(SteamAvatarImageSize steamAvatarImageSize)
		{
			return steamAvatarImageSize switch
			{
				SteamAvatarImageSize.Small => 32, 
				SteamAvatarImageSize.Medium => 64, 
				SteamAvatarImageSize.Large => 184, 
				_ => 0, 
			};
		}

		private async ValueTask GetRawAvatarImageBytesAndEnqueueForConversion(CSteamID steamUserId, SteamAvatarImageSize steamAvatarImageSize, int avatarImageHandle)
		{
			if (SteamUtils.GetImageSize(avatarImageHandle, out var pnWidth, out var pnHeight))
			{
				int width = (int)pnWidth;
				int height = (int)pnHeight;
				int num = 4;
				byte[] array = new byte[pnWidth * pnHeight * num];
				if (SteamUtils.GetImageRGBA(avatarImageHandle, array, array.Length))
				{
					AvatarImageTextureRequest item = new AvatarImageTextureRequest(steamUserId, steamAvatarImageSize, width, height, array);
					_avatarImageTextureRequests.Enqueue(item);
				}
			}
		}

		private void Update()
		{
			ConcurrentQueue<AvatarImageTextureRequest> avatarImageTextureRequests = _avatarImageTextureRequests;
			if (avatarImageTextureRequests == null || avatarImageTextureRequests.Count <= 0 || !_avatarImageTextureRequests.TryDequeue(out var result) || result.RawImage == null)
			{
				return;
			}
			Texture2D val = null;
			if (result.RawImage.Length == 0)
			{
				val = GetBlackTexture(result.Width, result.Height);
			}
			else
			{
				val = GetTextureFromRawImageData(result.Width, result.Height, result.RawImage);
				switch (result.AvatarImageSize)
				{
				case SteamAvatarImageSize.Small:
					_smallAvatarImageTextures[result.UserId] = val;
					break;
				case SteamAvatarImageSize.Medium:
					_mediumAvatarImageTextures[result.UserId] = val;
					break;
				case SteamAvatarImageSize.Large:
					_largeAvatarImageTextures[result.UserId] = val;
					break;
				}
			}
			if ((Object)(object)val != (Object)null)
			{
				this.OnAvatarImageTextureLoaded?.Invoke(result.UserId, result.AvatarImageSize, val);
			}
		}

		private void CacheTextureAsSprite(Texture2D texture, SteamAvatarImageSize steamAvatarImageSize, CSteamID steamUserId)
		{
			//IL_0023: Unknown result type (might be due to invalid IL or missing references)
			//IL_0032: Unknown result type (might be due to invalid IL or missing references)
			if (!((Object)(object)texture == (Object)null))
			{
				Sprite val = Sprite.Create(texture, new Rect(0f, 0f, (float)((Texture)texture).width, (float)((Texture)texture).height), new Vector2(0.5f, 0.5f), (float)((Texture)texture).width);
				((Object)val).hideFlags = (HideFlags)32;
				switch (steamAvatarImageSize)
				{
				case SteamAvatarImageSize.Small:
					_smallAvatarImageSprites[texture] = val;
					break;
				case SteamAvatarImageSize.Medium:
					_mediumAvatarImageSprites[texture] = val;
					break;
				case SteamAvatarImageSize.Large:
					_largeAvatarImageSprites[texture] = val;
					break;
				}
				if ((Object)(object)val != (Object)null)
				{
					this.OnAvatarImageSpriteLoaded?.Invoke(steamUserId, steamAvatarImageSize, val);
				}
			}
		}

		private static Texture2D GetBlackTexture(int width, int height)
		{
			//IL_0004: Unknown result type (might be due to invalid IL or missing references)
			//IL_000a: Expected O, but got Unknown
			//IL_0038: Unknown result type (might be due to invalid IL or missing references)
			//IL_003d: Unknown result type (might be due to invalid IL or missing references)
			Texture2D val = new Texture2D(width, height, (TextureFormat)4, false);
			((Object)val).hideFlags = (HideFlags)32;
			((Texture)val).filterMode = (FilterMode)2;
			((Texture)val).anisoLevel = 16;
			Color32[] array = (Color32[])(object)new Color32[width * height];
			for (int i = 0; i < array.Length; i++)
			{
				array[i] = new Color32((byte)0, (byte)0, (byte)0, byte.MaxValue);
			}
			val.SetPixels32(Il2CppStructArray<Color32>.op_Implicit(array));
			val.Apply();
			return val;
		}

		[HideFromIl2Cpp]
		private static Texture2D GetTextureFromRawImageData(int width, int height, byte[] rawImageData)
		{
			//IL_0004: Unknown result type (might be due to invalid IL or missing references)
			//IL_000a: Expected O, but got Unknown
			//IL_0062: Unknown result type (might be due to invalid IL or missing references)
			//IL_0067: Unknown result type (might be due to invalid IL or missing references)
			Texture2D val = new Texture2D(width, height, (TextureFormat)4, false);
			((Object)val).hideFlags = (HideFlags)32;
			((Texture)val).filterMode = (FilterMode)2;
			((Texture)val).anisoLevel = 16;
			Color32[] array = (Color32[])(object)new Color32[rawImageData.Length / 4];
			for (int i = 0; i < height; i++)
			{
				int num = height - 1 - i;
				for (int j = 0; j < width; j++)
				{
					int num2 = (i * width + j) * 4;
					array[num * width + j] = new Color32(rawImageData[num2], rawImageData[num2 + 1], rawImageData[num2 + 2], rawImageData[num2 + 3]);
				}
			}
			val.SetPixels32(Il2CppStructArray<Color32>.op_Implicit(array));
			val.Apply();
			return val;
		}

		[HideFromIl2Cpp]
		internal bool TryGetAvatarImageTexture(CSteamID steamUserId, SteamAvatarImageSize steamAvatarImageSize, out Texture2D avatarImageTexture)
		{
			if (steamUserId == CSteamID.Nil)
			{
				avatarImageTexture = null;
				return false;
			}
			switch (steamAvatarImageSize)
			{
			case SteamAvatarImageSize.Small:
				if (_smallAvatarImageTextures.TryGetValue(steamUserId, out avatarImageTexture))
				{
					return true;
				}
				avatarImageTexture = null;
				RequestAvatarImageTexture(steamUserId, steamAvatarImageSize);
				return false;
			case SteamAvatarImageSize.Medium:
				if (_mediumAvatarImageTextures.TryGetValue(steamUserId, out avatarImageTexture))
				{
					return true;
				}
				avatarImageTexture = null;
				RequestAvatarImageTexture(steamUserId, steamAvatarImageSize);
				return false;
			case SteamAvatarImageSize.Large:
				if (_largeAvatarImageTextures.TryGetValue(steamUserId, out avatarImageTexture))
				{
					return true;
				}
				avatarImageTexture = null;
				RequestAvatarImageTexture(steamUserId, steamAvatarImageSize);
				return false;
			default:
				avatarImageTexture = null;
				return false;
			}
		}

		internal bool TryGetAvatarImageSprite(CSteamID steamUserId, SteamAvatarImageSize steamAvatarImageSize, out Sprite avatarImageSprite)
		{
			if (steamUserId == CSteamID.Nil)
			{
				avatarImageSprite = null;
				return false;
			}
			switch (steamAvatarImageSize)
			{
			case SteamAvatarImageSize.Small:
			{
				if (TryGetAvatarImageTexture(steamUserId, steamAvatarImageSize, out var avatarImageTexture3) && _smallAvatarImageSprites.TryGetValue(avatarImageTexture3, out avatarImageSprite))
				{
					return true;
				}
				break;
			}
			case SteamAvatarImageSize.Medium:
			{
				if (TryGetAvatarImageTexture(steamUserId, steamAvatarImageSize, out var avatarImageTexture2) && _mediumAvatarImageSprites.TryGetValue(avatarImageTexture2, out avatarImageSprite))
				{
					return true;
				}
				break;
			}
			case SteamAvatarImageSize.Large:
			{
				if (TryGetAvatarImageTexture(steamUserId, steamAvatarImageSize, out var avatarImageTexture) && _largeAvatarImageSprites.TryGetValue(avatarImageTexture, out avatarImageSprite))
				{
					return true;
				}
				break;
			}
			}
			avatarImageSprite = null;
			return false;
		}

		private void OnDestroy()
		{
			UnsubscribeFromCallbacksAndCallResults();
			_avatarImageTextureRequests.Clear();
			_smallAvatarImageTextures.Clear();
			_mediumAvatarImageTextures.Clear();
			_largeAvatarImageTextures.Clear();
			_smallAvatarImageSprites.Clear();
			_mediumAvatarImageSprites.Clear();
			_largeAvatarImageSprites.Clear();
		}

		private void UnsubscribeFromCallbacksAndCallResults()
		{
			SteamFriendsImpl.OnAvatarImageLoaded = (SteamFriendsImpl.AvatarImageLoadedCallbackDelegate)Delegate.Remove(SteamFriendsImpl.OnAvatarImageLoaded, new SteamFriendsImpl.AvatarImageLoadedCallbackDelegate(OnAvatarImageLoaded));
			SteamFriendsImpl.OnPersonaStateChangeAvatar = (SteamFriendsImpl.PersonaStateChangeAvatarCallbackDelegate)Delegate.Remove(SteamFriendsImpl.OnPersonaStateChangeAvatar, new SteamFriendsImpl.PersonaStateChangeAvatarCallbackDelegate(OnPersonaStateChangeAvatar));
		}
	}
	internal enum SteamAvatarImageSize
	{
		None = -1,
		Small,
		Medium,
		Large
	}
	internal static class SteamFriendsImpl
	{
		internal delegate void GameLobbyJoinRequestedCallbackDelegate(CSteamID steamLobbyId, CSteamID steamUserId);

		internal delegate void GameRichPresenceJoinRequestedCallbackDelegate(CSteamID steamUserId, string connect);

		internal delegate void AvatarImageLoadedCallbackDelegate(CSteamID steamUserId, int imageHandle, int width, int height);

		internal delegate void PersonaStateChangeCallbackDelegate(CSteamID steamUserId, EPersonaChange flags);

		internal delegate void PersonaStateChangeNameCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeStatusCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeComeOnlineCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeGoneOfflineCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeGamePlayedCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeGameServerCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeAvatarCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeJoinedSourceCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeLeftSourceCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeRelationshipChangedCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeNameFirstSetCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeBroadcastCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeNicknameCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeSteamLevelCallbackDelegate(CSteamID steamUserId);

		internal delegate void PersonaStateChangeRichPresenceCallbackDelegate(CSteamID steamUserId);

		private static Callback<GameLobbyJoinRequested_t> _gameLobbyJoinRequestedCallback;

		private static Callback<GameRichPresenceJoinRequested_t> _gameRichPresenceJoinRequestedCallback;

		private static Callback<PersonaStateChange_t> _personaStateChangeCallback;

		private static Callback<AvatarImageLoaded_t> _avatarImageLoadedCallback;

		internal static GameLobbyJoinRequestedCallbackDelegate OnGameLobbyJoinRequested;

		internal static GameRichPresenceJoinRequestedCallbackDelegate OnGameRichPresenceJoinRequested;

		internal static AvatarImageLoadedCallbackDelegate OnAvatarImageLoaded;

		internal static PersonaStateChangeCallbackDelegate OnPersonaStateChange;

		internal static PersonaStateChangeNameCallbackDelegate OnPersonaStateChangeName;

		internal static PersonaStateChangeStatusCallbackDelegate OnPersonaStateChangeStatus;

		internal static PersonaStateChangeComeOnlineCallbackDelegate OnPersonaStateChangeComeOnline;

		internal static PersonaStateChangeGoneOfflineCallbackDelegate OnPersonaStateChangeGoneOffline;

		internal static PersonaStateChangeGamePlayedCallbackDelegate OnPersonaStateChangeGamePlayed;

		internal static PersonaStateChangeGameServerCallbackDelegate OnPersonaStateChangeGameServer;

		internal static PersonaStateChangeAvatarCallbackDelegate OnPersonaStateChangeAvatar;

		internal static PersonaStateChangeJoinedSourceCallbackDelegate OnPersonaStateChangeJoinedSource;

		internal static PersonaStateChangeLeftSourceCallbackDelegate OnPersonaStateChangeLeftSource;

		internal static PersonaStateChangeRelationshipChangedCallbackDelegate OnPersonaStateChangeRelationshipChanged;

		internal static PersonaStateChangeNameFirstSetCallbackDelegate OnPersonaStateChangeNameFirstSet;

		internal static PersonaStateChangeBroadcastCallbackDelegate OnPersonaStateChangeBroadcast;

		internal static PersonaStateChangeNicknameCallbackDelegate OnPersonaStateChangeNickname;

		internal static PersonaStateChangeSteamLevelCallbackDelegate OnPersonaStateChangeSteamLevel;

		internal static PersonaStateChangeRichPresenceCallbackDelegate OnPersonaStateChangeRichPresence;

		internal static bool IsSetup { get; private set; }

		internal static void Setup()
		{
			SetupCallbacksAndCallResults();
		}

		private static void SetupCallbacksAndCallResults()
		{
			_gameLobbyJoinRequestedCallback = Callback<GameLobbyJoinRequested_t>.Create(OnGameLobbyJoinRequestedCallback);
			_gameRichPresenceJoinRequestedCallback = Callback<GameRichPresenceJoinRequested_t>.Create(OnGameRichPresenceJoinRequestedCallback);
			_personaStateChangeCallback = Callback<PersonaStateChange_t>.Create(OnPersonaStateChangeCallback);
			_avatarImageLoadedCallback = Callback<AvatarImageLoaded_t>.Create(OnAvatarImageLoadedCallback);
			IsSetup = true;
		}

		internal static void Reset()
		{
			DisposeCallbacksAndCallResults();
		}

		private static void DisposeCallbacksAndCallResults()
		{
			_gameLobbyJoinRequestedCallback?.Dispose();
			_gameRichPresenceJoinRequestedCallback?.Dispose();
			_personaStateChangeCallback?.Dispose();
			_avatarImageLoadedCallback?.Dispose();
			IsSetup = false;
		}

		private static void OnGameLobbyJoinRequestedCallback(GameLobbyJoinRequested_t gameLobbyJoinRequested_t)
		{
			CSteamID steamIDLobby = gameLobbyJoinRequested_t.m_steamIDLobby;
			CSteamID steamIDFriend = gameLobbyJoinRequested_t.m_steamIDFriend;
			OnGameLobbyJoinRequested?.Invoke(steamIDLobby, steamIDFriend);
		}

		private static void OnGameRichPresenceJoinRequestedCallback(GameRichPresenceJoinRequested_t gameRichPresenceJoinRequested_t)
		{
			CSteamID steamIDFriend = gameRichPresenceJoinRequested_t.m_steamIDFriend;
			string rgchConnect = gameRichPresenceJoinRequested_t.m_rgchConnect;
			OnGameRichPresenceJoinRequested?.Invoke(steamIDFriend, rgchConnect);
		}

		private static void OnAvatarImageLoadedCallback(AvatarImageLoaded_t avatarImageLoaded_t)
		{
			CSteamID steamID = avatarImageLoaded_t.m_steamID;
			int iImage = avatarImageLoaded_t.m_iImage;
			int iWide = avatarImageLoaded_t.m_iWide;
			int iTall = avatarImageLoaded_t.m_iTall;
			if (steamID == CSteamID.Nil || iWide <= 0 || iTall <= 0)
			{
				throw new ArgumentException("avatarImageLoaded_t");
			}
			OnAvatarImageLoaded?.Invoke(steamID, iImage, iWide, iTall);
		}

		private static void OnPersonaStateChangeCallback(PersonaStateChange_t personaStateChange_t)
		{
			ulong ulSteamID = personaStateChange_t.m_ulSteamID;
			CSteamID steamUserId = new CSteamID(ulSteamID);
			EPersonaChange nChangeFlags = personaStateChange_t.m_nChangeFlags;
			OnPersonaStateChange?.Invoke(steamUserId, nChangeFlags);
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeName) != 0)
			{
				OnPersonaStateChangeName?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeStatus) != 0)
			{
				OnPersonaStateChangeStatus?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeComeOnline) != 0)
			{
				OnPersonaStateChangeComeOnline?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeGoneOffline) != 0)
			{
				OnPersonaStateChangeGoneOffline?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeGamePlayed) != 0)
			{
				OnPersonaStateChangeGamePlayed?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeGameServer) != 0)
			{
				OnPersonaStateChangeGameServer?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeAvatar) != 0)
			{
				OnPersonaStateChangeAvatar?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeJoinedSource) != 0)
			{
				OnPersonaStateChangeJoinedSource?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeLeftSource) != 0)
			{
				OnPersonaStateChangeLeftSource?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeRelationshipChanged) != 0)
			{
				OnPersonaStateChangeRelationshipChanged?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeNameFirstSet) != 0)
			{
				OnPersonaStateChangeNameFirstSet?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeBroadcast) != 0)
			{
				OnPersonaStateChangeBroadcast?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeNickname) != 0)
			{
				OnPersonaStateChangeNickname?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeSteamLevel) != 0)
			{
				OnPersonaStateChangeSteamLevel?.Invoke(steamUserId);
			}
			if ((nChangeFlags & EPersonaChange.k_EPersonaChangeRichPresence) != 0)
			{
				OnPersonaStateChangeRichPresence?.Invoke(steamUserId);
			}
		}
	}
	[RegisterTypeInIl2Cpp]
	internal sealed class SteamManager : MonoBehaviour
	{
		private const uint CMegabonkSteamAppId = 3405340u;

		private static readonly AppId_t MegabonkSteamAppId = new AppId_t(3405340u);

		internal static SteamManager Instance { get; set; }

		internal bool Initialized { get; set; }

		internal CSteamID CurrentUserId { get; set; }

		[HideFromIl2Cpp]
		internal SteamNetworkLobby Lobby { get; set; }

		[HideFromIl2Cpp]
		internal SteamNetworkServer Server { get; set; }

		[HideFromIl2Cpp]
		internal SteamNetworkClient Client { get; set; }

		internal SteamAvatarImageCache AvatarImageCache { get; set; }

		public SteamManager(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public SteamManager()
			: base(ClassInjector.DerivedConstructorPointer<SteamManager>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			if (Instance != null)
			{
				Object.DestroyImmediate((Object)(object)Instance);
			}
			else
			{
				Instance = this;
			}
		}

		private void Start()
		{
			SetupSteamApi();
			if (!Initialized)
			{
				ModLogger.Error("[SteamManager.Start] Aborting setting up further steam integrations..");
				return;
			}
			SetupSteamComponents();
			SetupSteamImplementations();
		}

		private bool VerifySteamOwnership()
		{
			try
			{
				byte[] pTicket = new byte[1024];
				uint pcbTicket = 0u;
				SteamNetworkingIdentity pSteamNetworkingIdentity = default(SteamNetworkingIdentity);
				HAuthTicket authSessionTicket = SteamUser.GetAuthSessionTicket(pTicket, 1024, out pcbTicket, ref pSteamNetworkingIdentity);
				if (authSessionTicket == HAuthTicket.Invalid || pcbTicket == 0)
				{
					ModLogger.Error("[VerifySteamOwnership] Failed to get auth session ticket");
					return false;
				}
				SteamUser.CancelAuthTicket(authSessionTicket);
				return true;
			}
			catch (Exception ex)
			{
				ModLogger.Error("[VerifySteamOwnership] Exception during verification: " + ex.Message);
				return false;
			}
		}

		private void SetupSteamApi()
		{
			if (!Packsize.Test())
			{
				ModLogger.Error("[SteamManager.SetupSteamApi] Packsize failed!");
				return;
			}
			if (!DllCheck.Test())
			{
				ModLogger.Error("[SteamManager.SetupSteamApi] DllCheck failed!");
				return;
			}
			if (SteamAPI.RestartAppIfNecessary(MegabonkSteamAppId))
			{
				ModLogger.Error("[SteamManager.SetupSteamApi] Steam not available or game was started through the executable!");
				Application.Quit();
				return;
			}
			if (!(Initialized = SteamAPI.Init()))
			{
				ModLogger.Error("[SteamManager.SetupSteamApi] Couldn't initialize SteamAPI!");
				return;
			}
			if (!VerifySteamOwnership())
			{
				ModLogger.Error("[SteamManager.SetupSteamApi] Steam ownership verification failed!");
				ToastNotification.Show("BonkWithFriends multiplayer requires legitimate game ownership.\nPlease purchase and launch Megabonk through Steam.", 10f);
				Initialized = false;
				SteamAPI.Shutdown();
				return;
			}
			AppId_t appID = SteamUtils.GetAppID();
			if (appID.m_AppId == 480)
			{
				ModLogger.Error("[SteamManager.SetupSteamApi] AppID 480 (Spacewar) detected - not supported.");
				Initialized = false;
				SteamAPI.Shutdown();
			}
			else
			{
				_ = appID != MegabonkSteamAppId;
				CurrentUserId = SteamUser.GetSteamID();
			}
		}

		private static void SteamNetworkingSocketsDebugOutput(ESteamNetworkingSocketsDebugOutputType nType, StringBuilder pszMsg)
		{
			if (pszMsg != null && pszMsg.Length > 0)
			{
				switch (nType)
				{
				case ESteamNetworkingSocketsDebugOutputType.k_ESteamNetworkingSocketsDebugOutputType_Bug:
				case ESteamNetworkingSocketsDebugOutputType.k_ESteamNetworkingSocketsDebugOutputType_Error:
					ModLogger.Error(pszMsg.ToString() ?? "");
					break;
				case ESteamNetworkingSocketsDebugOutputType.k_ESteamNetworkingSocketsDebugOutputType_None:
				case ESteamNetworkingSocketsDebugOutputType.k_ESteamNetworkingSocketsDebugOutputType_Important:
				case ESteamNetworkingSocketsDebugOutputType.k_ESteamNetworkingSocketsDebugOutputType_Warning:
				case ESteamNetworkingSocketsDebugOutputType.k_ESteamNetworkingSocketsDebugOutputType_Msg:
				case ESteamNetworkingSocketsDebugOutputType.k_ESteamNetworkingSocketsDebugOutputType_Verbose:
				case ESteamNetworkingSocketsDebugOutputType.k_ESteamNetworkingSocketsDebugOutputType_Debug:
				case ESteamNetworkingSocketsDebugOutputType.k_ESteamNetworkingSocketsDebugOutputType_Everything:
					break;
				}
			}
		}

		private void SetupSteamComponents()
		{
			AvatarImageCache = ((Component)this).gameObject.AddComponent<SteamAvatarImageCache>();
		}

		private void SetupSteamImplementations()
		{
			SteamNetworkingImpl.Setup();
			SteamMatchmakingImpl.Setup();
			SteamFriendsImpl.Setup();
			SteamPersonaNameCache.Setup();
		}

		private void FixedUpdate()
		{
			if (Initialized)
			{
				float fixedDeltaTime = Time.fixedDeltaTime;
				double fixedTimeAsDouble = Time.fixedTimeAsDouble;
				Server?.FixedUpdate(fixedDeltaTime, fixedTimeAsDouble);
				Client?.FixedUpdate(fixedDeltaTime, fixedTimeAsDouble);
			}
		}

		private void Update()
		{
			if (Initialized)
			{
				CheckInputs();
				SteamAPI.RunCallbacks();
				float deltaTime = Time.deltaTime;
				double timeAsDouble = Time.timeAsDouble;
				Server?.Update(deltaTime, timeAsDouble);
				Client?.Update(deltaTime, timeAsDouble);
				NetUpdate();
			}
		}

		private void NetUpdate()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client && PlayerSceneManager.HasPendingSceneLoad(out var sceneName))
			{
				PlayerSceneManager.ClearPendingSceneLoad();
				SceneManager.LoadScene(sceneName);
				return;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				MatchContext.Current?.HostEnemies.HostNetworkTick();
				MatchContext.Current?.FinalBossOrbs.SendOrbUpdates();
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				MatchContext.Current?.TimeSync.Update();
				MatchContext.Current?.RemoteEnemies.Update();
				PickupPatches.ProcessPendingSpawns();
				PickupPatches.ProcessPendingDespawns();
			}
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				MatchContext.Current?.LocalPlayer.BroadcastPlayerStateChange();
			}
		}

		private void CheckInputs()
		{
			PlayerHelper players = ReInput.players;
			if (players == null)
			{
				return;
			}
			IList<Player> allPlayers = players.AllPlayers;
			if (allPlayers == null)
			{
				return;
			}
			Player val = allPlayers[1];
			if (val == null)
			{
				return;
			}
			ControllerHelper controllers = val.controllers;
			if (controllers == null)
			{
				return;
			}
			Keyboard keyboard = controllers.Keyboard;
			if (keyboard != null && keyboard.GetModifierKey((ModifierKey)1))
			{
				if (keyboard.GetKeyDown((KeyCode)49))
				{
					SteamNetworkLobbyManager.CreateLobby();
				}
				if (keyboard.GetKeyDown((KeyCode)50))
				{
					SteamNetworkLobbyManager.OpenInviteDialog();
				}
				keyboard.GetKeyDown((KeyCode)51);
				if (keyboard.GetKeyDown((KeyCode)48))
				{
					SteamNetworkLobbyManager.LeaveLobby();
				}
			}
		}

		private void LateUpdate()
		{
			float deltaTime = Time.deltaTime;
			double timeAsDouble = Time.timeAsDouble;
			Server?.LateUpdate(deltaTime, timeAsDouble);
			Client?.LateUpdate(deltaTime, timeAsDouble);
		}

		private void OnDestroy()
		{
			SteamAPI.Shutdown();
			RemoveSteamImplementations();
			RemoveSteamComponents();
			Initialized = false;
		}

		private void RemoveSteamImplementations()
		{
			SteamNetworkLobbyManager.Reset();
			SteamPersonaNameCache.Reset();
			SteamFriendsImpl.Reset();
			SteamMatchmakingImpl.Reset();
			SteamNetworkingImpl.Reset();
		}

		private void RemoveSteamComponents()
		{
			Object.Destroy((Object)(object)AvatarImageCache);
		}
	}
	internal static class SteamMatchmakingImpl
	{
		internal delegate void LobbyCreatedCallResultDelegate(EResult flags, CSteamID steamLobbyId, bool ioFailure);

		internal delegate void LobbyCreatedOKCallResultDelegate(CSteamID steamLobbyId);

		internal delegate void LobbyCreatedFailCallResultDelegate();

		internal delegate void LobbyCreatedTimeoutCallResultDelegate();

		internal delegate void LobbyCreatedLimitExceededCallResultDelegate();

		internal delegate void LobbyCreatedAccessDeniedCallResultDelegate();

		internal delegate void LobbyCreatedNoConnectionCallResultDelegate();

		internal delegate void LobbyEnterCallResultDelegate(CSteamID steamLobbyId, bool lobbyLocked, EChatRoomEnterResponse flags, bool ioFailure);

		internal delegate void LobbyEnterSuccessCallResultDelegate(CSteamID steamLobbyId, bool lobbyLocked);

		internal delegate void LobbyEnterErrorCallResultDelegate(CSteamID steamLobbyId, bool lobbyLocked);

		internal delegate void LobbyEnterCallbackDelegate(CSteamID steamLobbyId, bool lobbyLocked, EChatRoomEnterResponse flags);

		internal delegate void LobbyEnterSuccessCallbackDelegate(CSteamID steamLobbyId, bool lobbyLocked);

		internal delegate void LobbyEnterErrorCallbackDelegate(CSteamID steamLobbyId, bool lobbyLocked);

		internal delegate void LobbyDataUpdateCallbackDelegate(CSteamID steamLobbyId, CSteamID steamMemberId, bool success);

		internal delegate void LobbyDataUpdateLobbyCallbackDelegate(CSteamID steamLobbyId);

		internal delegate void LobbyDataUpdateMemberCallbackDelegate(CSteamID steamLobbyId, CSteamID steamMemberId);

		internal delegate void LobbyChatUpdateCallbackDelegate(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator, EChatMemberStateChange flags);

		internal delegate void LobbyChatUpdateMemberEnteredCallbackDelegate(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator);

		internal delegate void LobbyChatUpdateMemberLeftCallbackDelegate(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator);

		internal delegate void LobbyChatUpdateMemberDisconnectedCallbackDelegate(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator);

		internal delegate void LobbyChatUpdateMemberKickedCallbackDelegate(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator);

		internal delegate void LobbyChatUpdateMemberBannedCallbackDelegate(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator);

		internal delegate void LobbyInviteCallbackDelegate(CSteamID steamUserIdInviter, CSteamID steamLobbyId, CSteamID steamGameId);

		internal delegate void LobbyLeaveDelegate(CSteamID steamLobbyId);

		internal delegate void LobbyMatchListCallResultDelegate(int lobbiesMatching, bool ioFailure);

		internal delegate void LobbyChatMsgCallbackDelegate(CSteamID steamLobbyId, CSteamID steamUserId, string message);

		private static CallResult<LobbyCreated_t> _lobbyCreatedCallResult;

		private static CallResult<LobbyMatchList_t> _lobbyMatchListCallResult;

		private static CallResult<LobbyEnter_t> _lobbyEnterCallResult;

		private static Callback<LobbyEnter_t> _lobbyEnterCallback;

		private static Callback<LobbyDataUpdate_t> _lobbyDataUpdateCallback;

		private static Callback<LobbyChatUpdate_t> _lobbyChatUpdateCallback;

		private static Callback<LobbyInvite_t> _lobbyInviteCallback;

		private static Callback<LobbyChatMsg_t> _lobbyChatMsgCallback;

		internal static LobbyCreatedCallResultDelegate OnLobbyCreated;

		internal static LobbyCreatedOKCallResultDelegate OnLobbyCreatedOK;

		internal static LobbyCreatedFailCallResultDelegate OnLobbyCreatedFail;

		internal static LobbyCreatedTimeoutCallResultDelegate OnLobbyCreatedTimeout;

		internal static LobbyCreatedLimitExceededCallResultDelegate OnLobbyCreatedLimitExceeded;

		internal static LobbyCreatedAccessDeniedCallResultDelegate OnLobbyCreatedAccessDenied;

		internal static LobbyCreatedNoConnectionCallResultDelegate OnLobbyCreatedNoConnection;

		internal static LobbyEnterCallResultDelegate OnLobbyEnterInitiated;

		internal static LobbyEnterSuccessCallResultDelegate OnLobbyEnterInitiatedSuccess;

		internal static LobbyEnterErrorCallResultDelegate OnLobbyEnterInitiatedError;

		internal static LobbyEnterCallbackDelegate OnLobbyEnterReceived;

		internal static LobbyEnterSuccessCallbackDelegate OnLobbyEnterReceivedSuccess;

		internal static LobbyEnterErrorCallbackDelegate OnLobbyEnterReceivedError;

		internal static LobbyDataUpdateCallbackDelegate OnLobbyDataUpdate;

		internal static LobbyDataUpdateLobbyCallbackDelegate OnLobbyDataUpdateLobby;

		internal static LobbyDataUpdateMemberCallbackDelegate OnLobbyDataUpdateMember;

		internal static LobbyChatUpdateCallbackDelegate OnLobbyChatUpdate;

		internal static LobbyChatUpdateMemberEnteredCallbackDelegate OnLobbyChatUpdateMemberEntered;

		internal static LobbyChatUpdateMemberLeftCallbackDelegate OnLobbyChatUpdateMemberLeft;

		internal static LobbyChatUpdateMemberDisconnectedCallbackDelegate OnLobbyChatUpdateMemberDisconnected;

		internal static LobbyChatUpdateMemberKickedCallbackDelegate OnLobbyChatUpdateMemberKicked;

		internal static LobbyChatUpdateMemberBannedCallbackDelegate OnLobbyChatUpdateMemberBanned;

		internal static LobbyInviteCallbackDelegate OnLobbyInvite;

		internal static LobbyLeaveDelegate OnLobbyLeave;

		internal static LobbyMatchListCallResultDelegate OnLobbyMatchList;

		internal static LobbyChatMsgCallbackDelegate OnLobbyChatMsg;

		internal static bool IsSetup { get; private set; }

		internal static void Setup()
		{
			SetupCallbacksAndCallResults();
		}

		private static void SetupCallbacksAndCallResults()
		{
			_lobbyCreatedCallResult = CallResult<LobbyCreated_t>.Create(OnLobbyCreatedCallResult);
			_lobbyEnterCallResult = CallResult<LobbyEnter_t>.Create(OnLobbyEnterCallResult);
			_lobbyEnterCallback = Callback<LobbyEnter_t>.Create(OnLobbyEnterCallback);
			_lobbyDataUpdateCallback = Callback<LobbyDataUpdate_t>.Create(OnLobbyDataUpdateCallback);
			_lobbyChatUpdateCallback = Callback<LobbyChatUpdate_t>.Create(OnLobbyChatUpdateCallback);
			_lobbyInviteCallback = Callback<LobbyInvite_t>.Create(OnLobbyInviteCallback);
			_lobbyMatchListCallResult = CallResult<LobbyMatchList_t>.Create(OnLobbyMatchListCallResult);
			_lobbyChatMsgCallback = Callback<LobbyChatMsg_t>.Create(OnLobbyChatMsgCallback);
		}

		internal static void Reset()
		{
			DisposeCallbacksAndCallResults();
		}

		private static void DisposeCallbacksAndCallResults()
		{
			_lobbyCreatedCallResult?.Dispose();
			_lobbyEnterCallResult?.Dispose();
			_lobbyEnterCallback?.Dispose();
			_lobbyDataUpdateCallback?.Dispose();
			_lobbyChatUpdateCallback?.Dispose();
			_lobbyInviteCallback?.Dispose();
			_lobbyMatchListCallResult?.Dispose();
			_lobbyChatMsgCallback?.Dispose();
			IsSetup = false;
		}

		internal static void SetCallResult<T>(SteamAPICall_t steamApiCallHandle) where T : struct
		{
			Type typeFromHandle = typeof(T);
			if (typeFromHandle == typeof(LobbyCreated_t))
			{
				_lobbyCreatedCallResult.Set(steamApiCallHandle);
			}
			else if (typeFromHandle == typeof(LobbyEnter_t))
			{
				_lobbyEnterCallResult.Set(steamApiCallHandle);
			}
			else if (typeFromHandle == typeof(LobbyMatchList_t))
			{
				_lobbyMatchListCallResult.Set(steamApiCallHandle);
			}
		}

		private static void OnLobbyCreatedCallResult(LobbyCreated_t lobbyCreated_t, bool ioFailure)
		{
			EResult eResult = lobbyCreated_t.m_eResult;
			ulong ulSteamIDLobby = lobbyCreated_t.m_ulSteamIDLobby;
			CSteamID steamLobbyId = new CSteamID(ulSteamIDLobby);
			OnLobbyCreated?.Invoke(eResult, steamLobbyId, ioFailure);
			if (ioFailure)
			{
				SteamNetworkLobbyManager.LobbyTypeQueue?.Dequeue();
				return;
			}
			switch (eResult)
			{
			case EResult.k_EResultOK:
				OnLobbyCreatedOK?.Invoke(steamLobbyId);
				break;
			case EResult.k_EResultFail:
				OnLobbyCreatedFail?.Invoke();
				break;
			case EResult.k_EResultTimeout:
				OnLobbyCreatedTimeout?.Invoke();
				break;
			case EResult.k_EResultLimitExceeded:
				OnLobbyCreatedLimitExceeded?.Invoke();
				break;
			case EResult.k_EResultAccessDenied:
				OnLobbyCreatedAccessDenied?.Invoke();
				break;
			case EResult.k_EResultNoConnection:
				OnLobbyCreatedNoConnection?.Invoke();
				break;
			}
		}

		private static void OnLobbyEnterCallResult(LobbyEnter_t lobbyEnter_t, bool ioFailure)
		{
			ulong ulSteamIDLobby = lobbyEnter_t.m_ulSteamIDLobby;
			CSteamID steamLobbyId = new CSteamID(ulSteamIDLobby);
			bool bLocked = lobbyEnter_t.m_bLocked;
			EChatRoomEnterResponse eChatRoomEnterResponse = (EChatRoomEnterResponse)lobbyEnter_t.m_EChatRoomEnterResponse;
			OnLobbyEnterInitiated?.Invoke(steamLobbyId, bLocked, eChatRoomEnterResponse, ioFailure);
			if (!ioFailure)
			{
				switch (eChatRoomEnterResponse)
				{
				case EChatRoomEnterResponse.k_EChatRoomEnterResponseSuccess:
					OnLobbyEnterInitiatedSuccess?.Invoke(steamLobbyId, bLocked);
					break;
				case EChatRoomEnterResponse.k_EChatRoomEnterResponseError:
					OnLobbyEnterInitiatedError?.Invoke(steamLobbyId, bLocked);
					break;
				}
			}
		}

		private static void OnLobbyEnterCallback(LobbyEnter_t lobbyEnter_t)
		{
			ulong ulSteamIDLobby = lobbyEnter_t.m_ulSteamIDLobby;
			CSteamID steamLobbyId = new CSteamID(ulSteamIDLobby);
			bool bLocked = lobbyEnter_t.m_bLocked;
			EChatRoomEnterResponse eChatRoomEnterResponse = (EChatRoomEnterResponse)lobbyEnter_t.m_EChatRoomEnterResponse;
			OnLobbyEnterReceived?.Invoke(steamLobbyId, bLocked, eChatRoomEnterResponse);
			switch (eChatRoomEnterResponse)
			{
			case EChatRoomEnterResponse.k_EChatRoomEnterResponseSuccess:
				OnLobbyEnterReceivedSuccess?.Invoke(steamLobbyId, bLocked);
				break;
			case EChatRoomEnterResponse.k_EChatRoomEnterResponseError:
				OnLobbyEnterReceivedError?.Invoke(steamLobbyId, bLocked);
				break;
			}
		}

		private static void OnLobbyDataUpdateCallback(LobbyDataUpdate_t lobbyDataUpdate_t)
		{
			ulong ulSteamIDLobby = lobbyDataUpdate_t.m_ulSteamIDLobby;
			CSteamID steamLobbyId = new CSteamID(ulSteamIDLobby);
			ulong ulSteamIDMember = lobbyDataUpdate_t.m_ulSteamIDMember;
			CSteamID steamMemberId = new CSteamID(ulSteamIDMember);
			bool flag = lobbyDataUpdate_t.m_bSuccess >= 1;
			OnLobbyDataUpdate?.Invoke(steamLobbyId, steamMemberId, flag);
			if (flag)
			{
				if (ulSteamIDLobby == ulSteamIDMember)
				{
					OnLobbyDataUpdateLobby?.Invoke(steamLobbyId);
				}
				else
				{
					OnLobbyDataUpdateMember?.Invoke(steamLobbyId, steamMemberId);
				}
			}
		}

		private static void OnLobbyChatUpdateCallback(LobbyChatUpdate_t lobbyChatUpdate_t)
		{
			ulong ulSteamIDLobby = lobbyChatUpdate_t.m_ulSteamIDLobby;
			CSteamID steamLobbyId = new CSteamID(ulSteamIDLobby);
			ulong ulSteamIDUserChanged = lobbyChatUpdate_t.m_ulSteamIDUserChanged;
			CSteamID steamUserIdRecipient = new CSteamID(ulSteamIDUserChanged);
			ulong ulSteamIDMakingChange = lobbyChatUpdate_t.m_ulSteamIDMakingChange;
			CSteamID steamUserIdInitiator = new CSteamID(ulSteamIDMakingChange);
			EChatMemberStateChange rgfChatMemberStateChange = (EChatMemberStateChange)lobbyChatUpdate_t.m_rgfChatMemberStateChange;
			OnLobbyChatUpdate?.Invoke(steamLobbyId, steamUserIdRecipient, steamUserIdInitiator, rgfChatMemberStateChange);
			if ((rgfChatMemberStateChange & EChatMemberStateChange.k_EChatMemberStateChangeEntered) != 0)
			{
				OnLobbyChatUpdateMemberEntered?.Invoke(steamLobbyId, steamUserIdRecipient, steamUserIdInitiator);
			}
			if ((rgfChatMemberStateChange & EChatMemberStateChange.k_EChatMemberStateChangeLeft) != 0)
			{
				OnLobbyChatUpdateMemberLeft?.Invoke(steamLobbyId, steamUserIdRecipient, steamUserIdInitiator);
			}
			if ((rgfChatMemberStateChange & EChatMemberStateChange.k_EChatMemberStateChangeDisconnected) != 0)
			{
				OnLobbyChatUpdateMemberDisconnected?.Invoke(steamLobbyId, steamUserIdRecipient, steamUserIdInitiator);
			}
			if ((rgfChatMemberStateChange & EChatMemberStateChange.k_EChatMemberStateChangeKicked) != 0)
			{
				OnLobbyChatUpdateMemberKicked?.Invoke(steamLobbyId, steamUserIdRecipient, steamUserIdInitiator);
			}
			if ((rgfChatMemberStateChange & EChatMemberStateChange.k_EChatMemberStateChangeBanned) != 0)
			{
				OnLobbyChatUpdateMemberBanned?.Invoke(steamLobbyId, steamUserIdRecipient, steamUserIdInitiator);
			}
		}

		private static void OnLobbyInviteCallback(LobbyInvite_t lobbyInvite_t)
		{
			ulong ulSteamIDUser = lobbyInvite_t.m_ulSteamIDUser;
			CSteamID steamUserIdInviter = new CSteamID(ulSteamIDUser);
			ulong ulSteamIDLobby = lobbyInvite_t.m_ulSteamIDLobby;
			CSteamID steamLobbyId = new CSteamID(ulSteamIDLobby);
			ulong ulGameID = lobbyInvite_t.m_ulGameID;
			CSteamID steamGameId = new CSteamID(ulGameID);
			OnLobbyInvite?.Invoke(steamUserIdInviter, steamLobbyId, steamGameId);
		}

		internal static void OnLobbyLeaveManual(CSteamID steamLobbyId)
		{
			if (!(steamLobbyId == CSteamID.Nil))
			{
				OnLobbyLeave?.Invoke(steamLobbyId);
			}
		}

		private static void OnLobbyMatchListCallResult(LobbyMatchList_t pCallback, bool bIOFailure)
		{
			int lobbiesMatching = (int)((!bIOFailure) ? pCallback.m_nLobbiesMatching : 0);
			OnLobbyMatchList?.Invoke(lobbiesMatching, bIOFailure);
		}

		private static void OnLobbyChatMsgCallback(LobbyChatMsg_t lobbyChatMsg_t)
		{
			ulong ulSteamIDLobby = lobbyChatMsg_t.m_ulSteamIDLobby;
			CSteamID cSteamID = new CSteamID(ulSteamIDLobby);
			ulong ulSteamIDUser = lobbyChatMsg_t.m_ulSteamIDUser;
			CSteamID steamUserId = new CSteamID(ulSteamIDUser);
			EChatEntryType eChatEntryType = (EChatEntryType)lobbyChatMsg_t.m_eChatEntryType;
			uint iChatID = lobbyChatMsg_t.m_iChatID;
			byte[] array = ArrayPool<byte>.Shared.Rent(4096);
			try
			{
				if (eChatEntryType == EChatEntryType.k_EChatEntryTypeChatMsg)
				{
					CSteamID pSteamIDUser;
					EChatEntryType peChatEntryType;
					int lobbyChatEntry = SteamMatchmaking.GetLobbyChatEntry(cSteamID, (int)iChatID, out pSteamIDUser, array, array.Length, out peChatEntryType);
					string message = Encoding.UTF8.GetString(array, 0, lobbyChatEntry);
					OnLobbyChatMsg?.Invoke(cSteamID, steamUserId, message);
				}
			}
			finally
			{
				ArrayPool<byte>.Shared.Return(array);
			}
		}
	}
	internal static class SteamNetworkingImpl
	{
		internal delegate void SteamNetConnectionStatusChangedCallbackDelegate(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState);

		internal delegate void SteamNetConnectionStatusChangedConnectionRequestCallbackDelegate(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState);

		internal delegate void SteamNetConnectionStatusChangedConnectionAcceptedCallbackDelegate(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState);

		internal delegate void SteamNetConnectionStatusChangedConnectionClosedOrRejectedCallbackDelegate(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState);

		internal delegate void SteamNetConnectionStatusChangedConnectionProblemCallbackDelegate(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState);

		internal delegate void SteamNetAuthenticationStatusCallbackDelegate(ESteamNetworkingAvailability flags, string debugMessage);

		internal delegate void SteamNetAuthenticationStatusCurrentCallbackDelegate();

		internal delegate void SteamRelayNetworkStatusCallbackDelegate(ESteamNetworkingAvailability availability, bool pingMeasurementInProgress, ESteamNetworkingAvailability networkConfigAvailability, ESteamNetworkingAvailability anyRelayAvailability, string debugMessage);

		internal delegate void SteamRelayNetworkStatusCurrentCallbackDelegate();

		private static Callback<SteamNetConnectionStatusChangedCallback_t> _steamNetConnectionStatusChangedCallback;

		private static Callback<SteamNetAuthenticationStatus_t> _steamNetAuthenticationStatusCallback;

		private static Callback<SteamRelayNetworkStatus_t> _steamRelayNetworkStatusCallback;

		internal static SteamNetConnectionStatusChangedCallbackDelegate OnSteamNetConnectionStatusChanged;

		internal static SteamNetConnectionStatusChangedConnectionRequestCallbackDelegate OnSteamNetConnectionStatusChangedConnectionRequest;

		internal static SteamNetConnectionStatusChangedConnectionAcceptedCallbackDelegate OnSteamNetConnectionStatusChangedConnectionAccepted;

		internal static SteamNetConnectionStatusChangedConnectionClosedOrRejectedCallbackDelegate OnSteamNetConnectionStatusChangedConnectionClosedOrRejected;

		internal static SteamNetConnectionStatusChangedConnectionProblemCallbackDelegate OnSteamNetConnectionStatusChangedConnectionProblem;

		internal static SteamNetAuthenticationStatusCallbackDelegate OnSteamNetAuthenticationStatus;

		internal static SteamNetAuthenticationStatusCurrentCallbackDelegate OnSteamNetAuthenticationStatusCurrent;

		internal static SteamRelayNetworkStatusCallbackDelegate OnSteamRelayNetworkStatus;

		internal static SteamRelayNetworkStatusCurrentCallbackDelegate OnSteamRelayNetworkStatusCurrent;

		internal static bool IsSetup { get; private set; }

		internal static void Setup()
		{
			SetupCallbacksAndCallResults();
			SetupSteamRelayNetworkAccess();
			SetupSteamAuthentication();
		}

		private static void SetupCallbacksAndCallResults()
		{
			_steamNetConnectionStatusChangedCallback = Callback<SteamNetConnectionStatusChangedCallback_t>.Create(OnSteamNetConnectionStatusChangedCallback);
			_steamNetAuthenticationStatusCallback = Callback<SteamNetAuthenticationStatus_t>.Create(OnSteamNetAuthenticationStatusCallback);
			_steamRelayNetworkStatusCallback = Callback<SteamRelayNetworkStatus_t>.Create(OnSteamRelayNetworkStatusCallback);
			IsSetup = true;
		}

		private static void SetupSteamRelayNetworkAccess()
		{
			SteamNetworkingUtils.InitRelayNetworkAccess();
		}

		private static void SetupSteamAuthentication()
		{
			SteamNetworkingSockets.InitAuthentication();
		}

		internal static void Reset()
		{
			DisposeCallbacksAndCallResults();
		}

		private static void DisposeCallbacksAndCallResults()
		{
			_steamNetConnectionStatusChangedCallback?.Dispose();
			_steamNetAuthenticationStatusCallback?.Dispose();
			_steamRelayNetworkStatusCallback?.Dispose();
			IsSetup = false;
		}

		private static void OnSteamNetConnectionStatusChangedCallback(SteamNetConnectionStatusChangedCallback_t steamNetConnectionStatusChangedCallback_t)
		{
			HSteamNetConnection hConn = steamNetConnectionStatusChangedCallback_t.m_hConn;
			SteamNetConnectionInfo_t info = steamNetConnectionStatusChangedCallback_t.m_info;
			ESteamNetworkingConnectionState eOldState = steamNetConnectionStatusChangedCallback_t.m_eOldState;
			HSteamListenSocket hListenSocket = info.m_hListenSocket;
			ESteamNetworkingConnectionState eState = info.m_eState;
			OnSteamNetConnectionStatusChanged?.Invoke(hConn, info, eOldState);
			if (eOldState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_None && eState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_Connecting && hListenSocket != HSteamListenSocket.Invalid)
			{
				OnSteamNetConnectionStatusChangedConnectionRequest?.Invoke(hConn, info, eOldState);
			}
			else if (eOldState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_Connecting && (eState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_Connected || eState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_FindingRoute) && hListenSocket == HSteamListenSocket.Invalid)
			{
				OnSteamNetConnectionStatusChangedConnectionAccepted?.Invoke(hConn, info, eOldState);
			}
			else if ((eOldState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_Connecting || eOldState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_Connected) && eState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_ClosedByPeer)
			{
				OnSteamNetConnectionStatusChangedConnectionClosedOrRejected?.Invoke(hConn, info, eOldState);
			}
			else if ((eOldState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_Connecting || eOldState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_Connected) && eState == ESteamNetworkingConnectionState.k_ESteamNetworkingConnectionState_ProblemDetectedLocally)
			{
				OnSteamNetConnectionStatusChangedConnectionProblem?.Invoke(hConn, info, eOldState);
			}
		}

		private static void OnSteamNetAuthenticationStatusCallback(SteamNetAuthenticationStatus_t steamNetAuthenticationStatus_t)
		{
			ESteamNetworkingAvailability eAvail = steamNetAuthenticationStatus_t.m_eAvail;
			string debugMsg = steamNetAuthenticationStatus_t.m_debugMsg;
			OnSteamNetAuthenticationStatus?.Invoke(eAvail, debugMsg);
			if (eAvail == ESteamNetworkingAvailability.k_ESteamNetworkingAvailability_Current)
			{
				OnSteamNetAuthenticationStatusCurrent?.Invoke();
			}
		}

		private static void OnSteamRelayNetworkStatusCallback(SteamRelayNetworkStatus_t steamRelayNetworkStatus_t)
		{
			ESteamNetworkingAvailability eAvail = steamRelayNetworkStatus_t.m_eAvail;
			bool pingMeasurementInProgress = steamRelayNetworkStatus_t.m_bPingMeasurementInProgress != 0;
			ESteamNetworkingAvailability eAvailNetworkConfig = steamRelayNetworkStatus_t.m_eAvailNetworkConfig;
			ESteamNetworkingAvailability eAvailAnyRelay = steamRelayNetworkStatus_t.m_eAvailAnyRelay;
			string debugMsg = steamRelayNetworkStatus_t.m_debugMsg;
			OnSteamRelayNetworkStatus?.Invoke(eAvail, pingMeasurementInProgress, eAvailNetworkConfig, eAvailAnyRelay, debugMsg);
			if (eAvail == ESteamNetworkingAvailability.k_ESteamNetworkingAvailability_Current && eAvailNetworkConfig == ESteamNetworkingAvailability.k_ESteamNetworkingAvailability_Current && eAvailAnyRelay == ESteamNetworkingAvailability.k_ESteamNetworkingAvailability_Current)
			{
				OnSteamRelayNetworkStatusCurrent?.Invoke();
			}
		}
	}
	internal static class SteamPersonaNameCache
	{
		private const int DefaultPersonaNameCacheSize = 16;

		private static ConcurrentDictionary<CSteamID, string> _steamPersonaNames = new ConcurrentDictionary<CSteamID, string>();

		private static CSteamID _currentSteamId;

		internal static void Setup()
		{
			_currentSteamId = SteamUser.GetSteamID();
			SubscribeToCallbacksAndCallResults();
		}

		private static void SubscribeToCallbacksAndCallResults()
		{
			SteamFriendsImpl.OnPersonaStateChangeName = (SteamFriendsImpl.PersonaStateChangeNameCallbackDelegate)Delegate.Combine(SteamFriendsImpl.OnPersonaStateChangeName, new SteamFriendsImpl.PersonaStateChangeNameCallbackDelegate(OnChangeName));
			SteamFriendsImpl.OnPersonaStateChangeNameFirstSet = (SteamFriendsImpl.PersonaStateChangeNameFirstSetCallbackDelegate)Delegate.Combine(SteamFriendsImpl.OnPersonaStateChangeNameFirstSet, new SteamFriendsImpl.PersonaStateChangeNameFirstSetCallbackDelegate(OnChangeName));
			SteamFriendsImpl.OnPersonaStateChangeNickname = (SteamFriendsImpl.PersonaStateChangeNicknameCallbackDelegate)Delegate.Combine(SteamFriendsImpl.OnPersonaStateChangeNickname, new SteamFriendsImpl.PersonaStateChangeNicknameCallbackDelegate(OnChangeName));
		}

		private static void OnChangeName(CSteamID steamUserId)
		{
			if (!(steamUserId == CSteamID.Nil))
			{
				string text = null;
				text = ((!(_currentSteamId == steamUserId)) ? SteamFriends.GetFriendPersonaName(steamUserId) : SteamFriends.GetPersonaName());
				if (!string.IsNullOrEmpty(text))
				{
					CachePersonaName(steamUserId, text);
				}
			}
		}

		internal static string GetOrRequestName(CSteamID steamUserId)
		{
			string value = null;
			if (!_steamPersonaNames.TryGetValue(steamUserId, out value))
			{
				value = ((!(steamUserId == _currentSteamId)) ? SteamFriends.GetFriendPersonaName(steamUserId) : SteamFriends.GetPersonaName());
				if (!string.IsNullOrEmpty(value))
				{
					CachePersonaName(steamUserId, value);
				}
				else
				{
					RequestPersonaName(steamUserId);
				}
			}
			return value;
		}

		private static void CachePersonaName(CSteamID steamUserId, string personaName)
		{
			_steamPersonaNames[steamUserId] = personaName;
		}

		private static void RequestPersonaName(CSteamID steamUserId)
		{
			if (!(steamUserId == _currentSteamId) && !SteamFriends.RequestUserInformation(steamUserId, bRequireNameOnly: true))
			{
				ModLogger.Error("Failed to get to get friend persona name, but user information is already available..");
			}
		}

		internal static void Reset()
		{
			UnsubscribeFromCallbacksAndCallResults();
			_currentSteamId = CSteamID.Nil;
			_steamPersonaNames.Clear();
		}

		private static void UnsubscribeFromCallbacksAndCallResults()
		{
			SteamFriendsImpl.OnPersonaStateChangeName = (SteamFriendsImpl.PersonaStateChangeNameCallbackDelegate)Delegate.Remove(SteamFriendsImpl.OnPersonaStateChangeName, new SteamFriendsImpl.PersonaStateChangeNameCallbackDelegate(OnChangeName));
			SteamFriendsImpl.OnPersonaStateChangeNameFirstSet = (SteamFriendsImpl.PersonaStateChangeNameFirstSetCallbackDelegate)Delegate.Remove(SteamFriendsImpl.OnPersonaStateChangeNameFirstSet, new SteamFriendsImpl.PersonaStateChangeNameFirstSetCallbackDelegate(OnChangeName));
			SteamFriendsImpl.OnPersonaStateChangeNickname = (SteamFriendsImpl.PersonaStateChangeNicknameCallbackDelegate)Delegate.Remove(SteamFriendsImpl.OnPersonaStateChangeNickname, new SteamFriendsImpl.PersonaStateChangeNicknameCallbackDelegate(OnChangeName));
		}
	}
}
namespace Megabonk.BonkWithFriends.Resources
{
	internal static class ResourceManager
	{
		private const string ResourceNamespace = "Megabonk.BonkWithFriends.Resources";

		private const string CustomUiAssetBundleResourceName = "Megabonk.BonkWithFriends.Resources.bonkwithfriends.bwf";

		private const string CustomUiAssetBundleManifestResourceName = "Megabonk.BonkWithFriends.Resources.bonkwithfriends.bwf.manifest";

		internal static byte[] CustomUiAssetBundleBytes;

		internal static byte[] CustomUiAssetBundleManifestBytes;

		static ResourceManager()
		{
			Assembly executingAssembly = Assembly.GetExecutingAssembly();
			using Stream stream = executingAssembly.GetManifestResourceStream("Megabonk.BonkWithFriends.Resources.bonkwithfriends.bwf");
			using BinaryReader binaryReader = new BinaryReader(stream);
			CustomUiAssetBundleBytes = binaryReader.ReadBytes((int)stream.Length);
			using Stream stream2 = executingAssembly.GetManifestResourceStream("Megabonk.BonkWithFriends.Resources.bonkwithfriends.bwf.manifest");
			using BinaryReader binaryReader2 = new BinaryReader(stream2);
			CustomUiAssetBundleManifestBytes = binaryReader2.ReadBytes((int)stream2.Length);
		}
	}
}
namespace Megabonk.BonkWithFriends.Net
{
	public static class Quant
	{
		public const float POS_UNIT = 0.05f;

		public const float VEL_UNIT = 0.16f;

		public const float AVEL_UNIT = 3f;

		public static short QPos(float v)
		{
			return (short)Mathf.Clamp(Mathf.RoundToInt(v / 0.05f), -32768, 32767);
		}

		public static float DPos(short q)
		{
			return (float)q * 0.05f;
		}

		public static sbyte QVel(float v)
		{
			return (sbyte)Mathf.Clamp(Mathf.RoundToInt(v / 0.16f), -128, 127);
		}

		public static float DVel(sbyte q)
		{
			return (float)q * 0.16f;
		}

		public static byte QYaw(float deg)
		{
			return (byte)Mathf.Clamp(Mathf.RoundToInt((deg % 360f + 360f) % 360f * (17f / 24f)), 0, 255);
		}

		public static float DYaw(byte q)
		{
			return (float)(int)q * 1.4117647f;
		}

		public static sbyte QAngVel(float degPerSec)
		{
			return (sbyte)Mathf.Clamp(Mathf.RoundToInt(degPerSec / 3f), -128, 127);
		}

		public static float DAngVel(sbyte q)
		{
			return (float)q * 3f;
		}
	}
}
namespace Megabonk.BonkWithFriends.Systems
{
	public static class EnemySystem
	{
		[NetworkMessageHandler(MessageType.EnemySpawned)]
		private static void HandleEnemySpawned(SteamNetworkMessage message)
		{
			//IL_0023: Unknown result type (might be due to invalid IL or missing references)
			//IL_0029: Unknown result type (might be due to invalid IL or missing references)
			//IL_002f: Unknown result type (might be due to invalid IL or missing references)
			EnemySpawnedMessage enemySpawnedMessage = message.Deserialize<EnemySpawnedMessage>();
			MatchContext.Current?.RemoteEnemies.SpawnRemoteEnemy(enemySpawnedMessage.EnemyId, enemySpawnedMessage.EnemyType, enemySpawnedMessage.Position, enemySpawnedMessage.EulerAngles, enemySpawnedMessage.VelXZ, enemySpawnedMessage.MaxHp, (EEnemyFlag)enemySpawnedMessage.Flags, enemySpawnedMessage.extraSizeMultiplier);
		}

		[NetworkMessageHandler(MessageType.EnemyDamaged)]
		private static void HandleEnemyDamaged(SteamNetworkMessage message)
		{
			EnemyDamagedMessage enemyDamagedMessage = message.Deserialize<EnemyDamagedMessage>();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				ApplyEnemyDamage(enemyDamagedMessage);
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				ApplyEnemyDamage(enemyDamagedMessage);
				SteamNetworkServer.Instance?.BroadcastMessageExcept(enemyDamagedMessage, message.SteamUserId);
			}
		}

		private static void ApplyEnemyDamage(EnemyDamagedMessage msg)
		{
			//IL_005c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0061: Unknown result type (might be due to invalid IL or missing references)
			//IL_006d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0079: Unknown result type (might be due to invalid IL or missing references)
			//IL_0085: Unknown result type (might be due to invalid IL or missing references)
			//IL_0091: Unknown result type (might be due to invalid IL or missing references)
			//IL_009d: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a9: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b6: Expected O, but got Unknown
			Enemy val = null;
			val = ((SteamNetworkManager.Mode != SteamNetworkMode.Server) ? MatchContext.Current?.RemoteEnemies.GetEnemy(msg.EnemyId) : MatchContext.Current?.HostEnemies.GetTrackedEnemy(msg.EnemyId));
			if ((Object)(object)val == (Object)null)
			{
				return;
			}
			DamageContainer val2 = new DamageContainer(msg.DamageProcCoefficient, msg.DamageSource)
			{
				damage = msg.Damage,
				damageEffect = (EDamageEffect)msg.DamageEffect,
				damageBlockedByArmor = msg.DamageBlockedByArmor,
				crit = msg.DamageIsCrit,
				element = (EElement)msg.DamageElement,
				flags = (DcFlags)msg.DamageFlags,
				knockback = msg.DamageKnockback
			};
			EnemyPatches.SetApplyingNetworkDamage(applying: true);
			try
			{
				val.Damage(val2);
			}
			finally
			{
				EnemyPatches.SetApplyingNetworkDamage(applying: false);
			}
		}

		[NetworkMessageHandler(MessageType.EnemyDied)]
		private static void HandleEnemyDied(SteamNetworkMessage message)
		{
			EnemyDiedMessage enemyDiedMessage = message.Deserialize<EnemyDiedMessage>();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				MatchContext.Current?.RemoteEnemies.RemoveEnemy(enemyDiedMessage.EnemyId, _hostkilled: true);
			}
			else if (Object.op_Implicit((Object)(object)MatchContext.Current?.HostEnemies.GetTrackedEnemy(enemyDiedMessage.EnemyId)))
			{
				MatchContext.Current?.HostEnemies.UnregisterHostEnemy(enemyDiedMessage.EnemyId, _clientKilled: true);
				SteamNetworkServer.Instance.BroadcastMessageExcept(enemyDiedMessage, message.SteamUserId);
			}
		}

		[NetworkMessageHandler(MessageType.EnemyStateBatch)]
		private static void HandleEnemyStateBatch(SteamNetworkMessage message)
		{
			foreach (EnemyStateBatchMessage.EnemyState state in message.Deserialize<EnemyStateBatchMessage>().States)
			{
				MatchContext current2 = MatchContext.Current;
				if (current2 != null && current2.RemoteEnemies.HasEnemy(state.EnemyId))
				{
					MatchContext.Current?.RemoteEnemies.OnEnemyStateSnapshot(state.EnemyId, state.PosX, state.PosY, state.PosZ, state.YawQuantized, state.VelX, state.VelZ, state.AngVelQuantized, state.Hp, state.MaxHp, state.ServerTime, state.Seq);
				}
			}
		}

		[NetworkMessageHandler(MessageType.EnemySpecialAttack)]
		private static void HandleEnemySpecialAttack(SteamNetworkMessage message)
		{
			EnemySpecialAttackMessage enemySpecialAttackMessage = message.Deserialize<EnemySpecialAttackMessage>();
			Enemy val = MatchContext.Current?.RemoteEnemies.GetEnemy(enemySpecialAttackMessage.EnemyId);
			if ((Object)(object)val == (Object)null || val.specialAttackController == null)
			{
				return;
			}
			EnemySpecialAttack val2 = null;
			Enumerator<EnemySpecialAttack> enumerator = val.specialAttackController.attacks.GetEnumerator();
			while (enumerator.MoveNext())
			{
				EnemySpecialAttack current = enumerator.Current;
				if (current.attackName == enemySpecialAttackMessage.AttackName)
				{
					val2 = current;
					break;
				}
			}
			if (val2 == null)
			{
				return;
			}
			Rigidbody val3 = null;
			ulong steamID = SteamUser.GetSteamID().m_SteamID;
			val3 = ((enemySpecialAttackMessage.TargetSteamId != steamID) ? (MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(enemySpecialAttackMessage.TargetSteamId)))?.CachedRigidbody : MatchContext.Current?.LocalPlayer.LocalPlayer?.CachedRigidbody);
			if ((Object)(object)val3 != (Object)null)
			{
				val.target = val3;
			}
			EnemySpecialAttackPatches.SetAllowFromNetwork(allow: true);
			try
			{
				val.specialAttackController.UseSpecialAttack(val2);
			}
			finally
			{
				EnemySpecialAttackPatches.SetAllowFromNetwork(allow: false);
			}
		}
	}
	public static class FinalBossSystem
	{
		[NetworkMessageHandler(MessageType.FinalBossOrbSpawned)]
		private static void HandleOrbSpawned(SteamNetworkMessage message)
		{
			//IL_004d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0052: Unknown result type (might be due to invalid IL or missing references)
			//IL_0090: Unknown result type (might be due to invalid IL or missing references)
			//IL_00fb: Unknown result type (might be due to invalid IL or missing references)
			//IL_0158: Unknown result type (might be due to invalid IL or missing references)
			FinalBossOrbSpawnedMessage finalBossOrbSpawnedMessage = message.Deserialize<FinalBossOrbSpawnedMessage>();
			if (SteamNetworkManager.Mode != SteamNetworkMode.Client || !Object.op_Implicit((Object)(object)MusicController.Instance) || !Object.op_Implicit((Object)(object)MusicController.Instance.finalFightController))
			{
				return;
			}
			Enemy boss = MusicController.Instance.finalFightController.boss;
			if (!Object.op_Implicit((Object)(object)boss))
			{
				return;
			}
			Vector3 position = ((Component)boss).transform.position;
			GameObject val = null;
			switch (finalBossOrbSpawnedMessage.OrbType)
			{
			case OrbType.Bleed:
			{
				val = Object.Instantiate<GameObject>(MusicController.Instance.finalFightController.orbBleed);
				val.transform.position = position;
				BossOrbBleed component2 = val.GetComponent<BossOrbBleed>();
				if (Object.op_Implicit((Object)(object)component2))
				{
					component2.isFired = false;
					component2.Set(boss, MusicController.Instance.finalFightController.currentPhase, MusicController.Instance.finalFightController.currentPhase + 1, 1);
				}
				break;
			}
			case OrbType.Following:
			{
				val = Object.Instantiate<GameObject>(MusicController.Instance.finalFightController.orbFollowing);
				val.transform.position = position;
				BossOrb component3 = val.GetComponent<BossOrb>();
				if (Object.op_Implicit((Object)(object)component3))
				{
					component3.isFired = false;
					component3.Set(1f, MusicController.Instance.finalFightController.currentPhase, boss, 1, 1);
				}
				break;
			}
			case OrbType.Shooty:
			{
				val = Object.Instantiate<GameObject>(MusicController.Instance.finalFightController.orbShooty);
				val.transform.position = position;
				BossOrbShooty component = val.GetComponent<BossOrbShooty>();
				if (Object.op_Implicit((Object)(object)component))
				{
					component.isFired = false;
					component.Set(boss, MusicController.Instance.finalFightController.currentPhase, MusicController.Instance.finalFightController.currentPhase + 1, 1);
				}
				break;
			}
			}
			if (Object.op_Implicit((Object)(object)val))
			{
				val.AddComponent<BossOrbInterpolator>().Initialize(val);
				MatchContext.Current?.FinalBossOrbs.SetOrbTarget(finalBossOrbSpawnedMessage.TargetId, val, finalBossOrbSpawnedMessage.OrbId);
			}
		}

		[NetworkMessageHandler(MessageType.FinalBossOrbsUpdate)]
		private static void HandleOrbsUpdate(SteamNetworkMessage message)
		{
			//IL_0077: Unknown result type (might be due to invalid IL or missing references)
			//IL_007c: Unknown result type (might be due to invalid IL or missing references)
			FinalBossOrbsUpdateMessage finalBossOrbsUpdateMessage = message.Deserialize<FinalBossOrbsUpdateMessage>();
			if (SteamNetworkManager.Mode != SteamNetworkMode.Client)
			{
				return;
			}
			foreach (BossOrbModel orb in finalBossOrbsUpdateMessage.Orbs)
			{
				GameObject val = MatchContext.Current?.FinalBossOrbs.GetOrbById(orb.Id);
				if (Object.op_Implicit((Object)(object)val))
				{
					BossOrbInterpolator component = val.GetComponent<BossOrbInterpolator>();
					if (Object.op_Implicit((Object)(object)component))
					{
						component.AddSnapshot(new BossOrbSnapshot
						{
							Timestamp = Time.timeAsDouble,
							Position = orb.Position
						});
					}
				}
			}
		}

		[NetworkMessageHandler(MessageType.FinalBossOrbDestroyed)]
		private static void HandleOrbDestroyed(SteamNetworkMessage message)
		{
			FinalBossOrbDestroyedMessage finalBossOrbDestroyedMessage = message.Deserialize<FinalBossOrbDestroyedMessage>();
			GameObject val = MatchContext.Current?.FinalBossOrbs.GetOrbById(finalBossOrbDestroyedMessage.OrbId);
			if (Object.op_Implicit((Object)(object)val))
			{
				Object.Destroy((Object)(object)val);
				MatchContext.Current?.FinalBossOrbs.RemoveOrb(val);
			}
		}

		[NetworkMessageHandler(MessageType.BossLampCharge)]
		private static void HandleBossLampCharge(SteamNetworkMessage message)
		{
			BossLampChargeMessage bossLampChargeMessage = message.Deserialize<BossLampChargeMessage>();
			GameObject val = MatchContext.Current?.SpawnedObjects.GetObject(bossLampChargeMessage.LampId);
			if (!Object.op_Implicit((Object)(object)val))
			{
				return;
			}
			BossLamp component = val.GetComponent<BossLamp>();
			if (Object.op_Implicit((Object)(object)component))
			{
				MatchContext current = MatchContext.Current;
				if (current != null)
				{
					current.SpawnedObjects.CanSendNetworkMessages = false;
				}
				if (bossLampChargeMessage.IsStarting)
				{
					component.OnTriggerEnter();
				}
				else
				{
					component.OnTriggerExit();
				}
				MatchContext current2 = MatchContext.Current;
				if (current2 != null)
				{
					current2.SpawnedObjects.CanSendNetworkMessages = true;
				}
			}
		}

		[NetworkMessageHandler(MessageType.BossPylonCharge)]
		private static void HandleBossPylonCharge(SteamNetworkMessage message)
		{
			BossPylonChargeMessage bossPylonChargeMessage = message.Deserialize<BossPylonChargeMessage>();
			GameObject val = MatchContext.Current?.SpawnedObjects.GetObject(bossPylonChargeMessage.PylonId);
			if (!Object.op_Implicit((Object)(object)val))
			{
				return;
			}
			BossPylon component = val.GetComponent<BossPylon>();
			if (Object.op_Implicit((Object)(object)component))
			{
				MatchContext current = MatchContext.Current;
				if (current != null)
				{
					current.SpawnedObjects.CanSendNetworkMessages = false;
				}
				if (bossPylonChargeMessage.IsStarting)
				{
					component.OnTriggerEnter();
				}
				else
				{
					component.OnTriggerExit();
				}
				MatchContext current2 = MatchContext.Current;
				if (current2 != null)
				{
					current2.SpawnedObjects.CanSendNetworkMessages = true;
				}
			}
		}
	}
	public static class MapControllerSystem
	{
		[NetworkMessageHandler(MessageType.LoadStage)]
		private static void HandleLoadStage(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				MapController.index = message.Deserialize<LoadStageMessage>().StageIndex - 1;
				MapControllerPatches.SetNetworkLoading(value: true);
				MapController.LoadNextStage();
			}
		}
	}
	public static class NetworkTimeSystem
	{
		[NetworkMessageHandler(MessageType.TimeSyncRequest)]
		private static void HandleTimeSyncRequest(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				TimeSyncRequestMessage timeSyncRequestMessage = message.Deserialize<TimeSyncRequestMessage>();
				TimeSyncResponseMessage tMsg = new TimeSyncResponseMessage
				{
					ClientSendTime = timeSyncRequestMessage.ClientSendTime,
					ServerReceiveTime = Time.unscaledTime
				};
				SteamNetworkServer.Instance.SendMessage(tMsg, message.SteamUserId);
			}
		}

		[NetworkMessageHandler(MessageType.TimeSyncResponse)]
		private static void HandleTimeSyncResponse(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				TimeSyncResponseMessage timeSyncResponseMessage = message.Deserialize<TimeSyncResponseMessage>();
				MatchContext.Current?.TimeSync.ProcessTimeSyncResponse(timeSyncResponseMessage.ServerReceiveTime, timeSyncResponseMessage.ClientSendTime);
			}
		}
	}
	public static class PickupSystem
	{
		[NetworkMessageHandler(MessageType.PickupSpawned)]
		private static void HandlePickupSpawned(SteamNetworkMessage message)
		{
			PickupSpawnedMessage msg = message.Deserialize<PickupSpawnedMessage>();
			MatchContext.Current?.Pickups?.HandlePickupSpawn(msg);
		}

		[NetworkMessageHandler(MessageType.PickupCollected)]
		private static void HandlePickupCollected(SteamNetworkMessage message)
		{
			PickupCollectedMessage pickupCollectedMessage = message.Deserialize<PickupCollectedMessage>();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				Pickup val = MatchContext.Current?.Pickups?.GetPickup(pickupCollectedMessage.PickupId);
				if (!((Object)(object)val == (Object)null) && !val.pickedUp)
				{
					ulong steamID = message.SteamUserId.m_SteamID;
					MatchContext.Current?.Pickups?.SetPickupOwner(pickupCollectedMessage.PickupId, steamID);
					SteamNetworkServer.Instance?.BroadcastMessage(new PickupCollectedMessage
					{
						PickupId = pickupCollectedMessage.PickupId,
						CollectorSteamId = steamID
					});
					ProcessCollectionLocally(pickupCollectedMessage.PickupId, steamID);
				}
			}
			else
			{
				ProcessCollectionLocally(pickupCollectedMessage.PickupId, pickupCollectedMessage.CollectorSteamId);
			}
		}

		private static void ProcessCollectionLocally(int pickupId, ulong collectorSteamId)
		{
			Pickup val = MatchContext.Current?.Pickups?.GetPickup(pickupId);
			if ((Object)(object)val == (Object)null || val.pickedUp)
			{
				return;
			}
			MatchContext.Current?.Pickups?.SetPickupOwner(pickupId, collectorSteamId);
			ulong steamID = SteamUser.GetSteamID().m_SteamID;
			Transform transform;
			if (collectorSteamId == steamID)
			{
				transform = ((Component)GameManager.Instance.player).transform;
			}
			else
			{
				NetworkedPlayer networkedPlayer = MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(collectorSteamId));
				if ((Object)(object)networkedPlayer == (Object)null || !Object.op_Implicit((Object)(object)networkedPlayer.ModelInstance))
				{
					MatchContext.Current?.Pickups?.ProcessPickupCollection(pickupId);
					return;
				}
				transform = networkedPlayer.ModelInstance.transform;
			}
			MatchContext current = MatchContext.Current;
			if (current != null)
			{
				PickupSpawnManager pickups = current.Pickups;
				if (pickups != null)
				{
					pickups.IsProcessingRemoteCollection = true;
				}
			}
			val.StartFollowingPlayer(transform);
			MatchContext current2 = MatchContext.Current;
			if (current2 != null)
			{
				PickupSpawnManager pickups2 = current2.Pickups;
				if (pickups2 != null)
				{
					pickups2.IsProcessingRemoteCollection = false;
				}
			}
		}

		[NetworkMessageHandler(MessageType.PickupDespawned)]
		private static void HandlePickupDespawned(SteamNetworkMessage message)
		{
			PickupDespawnedMessage pickupDespawnedMessage = message.Deserialize<PickupDespawnedMessage>();
			MatchContext.Current?.Pickups?.QueueRemotePickupDespawn(pickupDespawnedMessage.PickupId);
		}
	}
}
namespace Megabonk.BonkWithFriends.Networking
{
	internal interface IAsyncNetworkSerializable
	{
		internal ValueTask SerializeAsync(NetworkWriter networkWriter);

		internal ValueTask DeserializeAsync(NetworkReader networkReader);
	}
	internal interface INetworkSerializable
	{
		internal void Serialize(NetworkWriter networkWriter);

		internal void Deserialize(NetworkReader networkReader);
	}
}
namespace Megabonk.BonkWithFriends.Networking.Steam
{
	internal sealed class SteamNetworkClient : IDisposable, IAsyncDisposable
	{
		private const int SteamNetworkMessageBufferSize = 128;

		private const int MaxNetworkReadsPerFrame = 4;

		private const double SendRate = 1.0 / 60.0;

		private const float KeepAliveInterval = 5f;

		internal static SteamNetworkClient Instance;

		private readonly object _syncRoot = new object();

		private bool _disposedValue;

		private bool _netAuthenticationStatusCurrent;

		private bool _relayNetworkAccessStatusCurrent;

		private HSteamNetConnection _steamNetConnectionHandle;

		private SteamNetworkingIdentity _remoteSteamNetworkingIdentity;

		private CSteamID _remoteSteamUserId;

		private IntPtr[] _steamNetworkMessageReceiveBuffer;

		private IntPtr[] _steamNetworkMessageSendBuffer;

		private long[] _steamNetworkMessageSendResults;

		private ConcurrentQueue<SteamNetworkMessage> _steamNetworkMessageSendQueue;

		private NetworkMessageDispatcher _networkMessageDispatcher;

		private double _lastSendTime;

		private float _keepAliveTimer = 5f;

		internal ClientConnectedDelegate OnConnected;

		internal bool IsConnected { get; private set; }

		internal bool SafeRW { get; private set; }

		internal SteamNetworkClientState State { get; private set; }

		internal SteamNetworkClient(bool safeReadingAndWriting = true)
		{
			if (Instance != null)
			{
				throw new InvalidOperationException();
			}
			Instance = this;
			_networkMessageDispatcher = new NetworkMessageDispatcher(isServer: false);
			_steamNetworkMessageReceiveBuffer = new IntPtr[128];
			_steamNetworkMessageSendBuffer = new IntPtr[128];
			_steamNetworkMessageSendResults = new long[128];
			_steamNetworkMessageSendQueue = new ConcurrentQueue<SteamNetworkMessage>();
			SafeRW = safeReadingAndWriting;
			Setup();
		}

		private void Setup()
		{
			SubscribeToCallbacksAndCallResults();
		}

		private void SubscribeToCallbacksAndCallResults()
		{
			SteamNetworkingImpl.OnSteamNetAuthenticationStatusCurrent = (SteamNetworkingImpl.SteamNetAuthenticationStatusCurrentCallbackDelegate)Delegate.Combine(SteamNetworkingImpl.OnSteamNetAuthenticationStatusCurrent, new SteamNetworkingImpl.SteamNetAuthenticationStatusCurrentCallbackDelegate(OnSteamNetAuthenticationStatusCurrent));
			SteamNetworkingImpl.OnSteamRelayNetworkStatusCurrent = (SteamNetworkingImpl.SteamRelayNetworkStatusCurrentCallbackDelegate)Delegate.Combine(SteamNetworkingImpl.OnSteamRelayNetworkStatusCurrent, new SteamNetworkingImpl.SteamRelayNetworkStatusCurrentCallbackDelegate(OnSteamRelayNetworkStatusCurrent));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionAccepted = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionAcceptedCallbackDelegate)Delegate.Combine(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionAccepted, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionAcceptedCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionAccepted));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionClosedOrRejected = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionClosedOrRejectedCallbackDelegate)Delegate.Combine(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionClosedOrRejected, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionClosedOrRejectedCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionClosedOrRejected));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionProblem = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionProblemCallbackDelegate)Delegate.Combine(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionProblem, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionProblemCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionProblem));
		}

		private bool IsReadyToConnect()
		{
			if (_netAuthenticationStatusCurrent)
			{
				return _relayNetworkAccessStatusCurrent;
			}
			return false;
		}

		internal void Connect(CSteamID steamUserId)
		{
			SteamNetworkingIdentity identityRemote = default(SteamNetworkingIdentity);
			identityRemote.SetSteamID(steamUserId);
			SteamNetworkingConfigValue_t[] array = Array.Empty<SteamNetworkingConfigValue_t>();
			_steamNetConnectionHandle = SteamNetworkingSockets.ConnectP2P(ref identityRemote, 0, array.Length, array);
		}

		private void OnSteamNetAuthenticationStatusCurrent()
		{
			_netAuthenticationStatusCurrent = true;
		}

		private void OnSteamRelayNetworkStatusCurrent()
		{
			_relayNetworkAccessStatusCurrent = true;
		}

		private void OnSteamNetConnectionStatusChangedConnectionAccepted(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState)
		{
			if (IsConnected || connection == HSteamNetConnection.Invalid)
			{
				SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
				return;
			}
			CSteamID nil = CSteamID.Nil;
			SteamNetworkingIdentity identityRemote = connectionInfo.m_identityRemote;
			if (identityRemote.m_eType == ESteamNetworkingIdentityType.k_ESteamNetworkingIdentityType_SteamID)
			{
				nil = identityRemote.GetSteamID();
				if (nil == CSteamID.Nil)
				{
					SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionAccepted] Steam user id null!");
					return;
				}
				if (_steamNetConnectionHandle != connection)
				{
					SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					throw new InvalidOperationException("connection");
				}
				_remoteSteamNetworkingIdentity = identityRemote;
				_remoteSteamUserId = nil;
				IsConnected = true;
				HandshakeSystem.SendClientHello();
				OnConnected?.Invoke();
				return;
			}
			SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
			throw new ArgumentException("steamNetworkingIdentity");
		}

		private void OnSteamNetConnectionStatusChangedConnectionClosedOrRejected(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState)
		{
			if (!IsConnected || connection == HSteamNetConnection.Invalid)
			{
				SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
				return;
			}
			CSteamID nil = CSteamID.Nil;
			SteamNetworkingIdentity identityRemote = connectionInfo.m_identityRemote;
			if (identityRemote.m_eType == ESteamNetworkingIdentityType.k_ESteamNetworkingIdentityType_SteamID)
			{
				nil = identityRemote.GetSteamID();
				if (nil == CSteamID.Nil)
				{
					SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionClosedOrRejected] Steam user id null!");
				}
				else
				{
					SteamNetworkLobbyManager.LeaveLobby();
					SteamNetworkManager.DestroyClient();
					IsConnected = false;
				}
				return;
			}
			SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
			throw new ArgumentException("steamNetworkingIdentity");
		}

		private void OnSteamNetConnectionStatusChangedConnectionProblem(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState)
		{
			if (!IsConnected || connection == HSteamNetConnection.Invalid)
			{
				SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
				return;
			}
			CSteamID nil = CSteamID.Nil;
			SteamNetworkingIdentity identityRemote = connectionInfo.m_identityRemote;
			if (identityRemote.m_eType == ESteamNetworkingIdentityType.k_ESteamNetworkingIdentityType_SteamID)
			{
				nil = identityRemote.GetSteamID();
				if (nil == CSteamID.Nil)
				{
					SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionProblem] Steam user id null!");
				}
				else
				{
					SteamNetworkLobbyManager.LeaveLobby();
					SteamNetworkManager.DestroyClient();
					IsConnected = false;
				}
				return;
			}
			SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
			throw new ArgumentException("steamNetworkingIdentity");
		}

		internal void FixedUpdate(float fixedDeltaTime, double fixedTimeAsDouble)
		{
		}

		internal void Update(float deltaTime, double timeAsDouble)
		{
			if (_steamNetConnectionHandle == HSteamNetConnection.Invalid || !IsConnected)
			{
				return;
			}
			int num = 0;
			int num2 = 0;
			do
			{
				num2 = SteamNetworkingSockets.ReceiveMessagesOnConnection(_steamNetConnectionHandle, _steamNetworkMessageReceiveBuffer, _steamNetworkMessageReceiveBuffer.Length);
				if (num2 <= 0)
				{
					break;
				}
				if (SafeRW)
				{
					SafeReceiveAndDispatch(num2);
				}
				else
				{
					UnsafeReceiveAndDispatch(num2);
				}
				num++;
				if (num >= 4)
				{
					num = 0;
					break;
				}
			}
			while (num2 == _steamNetworkMessageReceiveBuffer.Length);
			if (timeAsDouble - _lastSendTime > 1.0 / 60.0)
			{
				int num3 = 0;
				SteamNetworkMessage result;
				while (_steamNetworkMessageSendQueue.TryDequeue(out result))
				{
					if (result == null)
					{
						continue;
					}
					try
					{
						if (SafeRW)
						{
							SafeSend(result, num3);
						}
						else
						{
							UnsafeSend(result, num3);
						}
					}
					catch (Exception ex)
					{
						ModLogger.Error($"[Update] Failed to send message - Size: {result.GetLength()}, Flags: {result.SendFlags}, Error: {ex.Message}");
					}
					finally
					{
						NetworkMessagePool.Return(result);
					}
					num3++;
					if (num3 >= _steamNetworkMessageSendBuffer.Length)
					{
						break;
					}
				}
				_lastSendTime = timeAsDouble;
			}
			_keepAliveTimer -= deltaTime;
			if (_keepAliveTimer <= 0f)
			{
				SendMessage(new KeepAliveMessage());
				_keepAliveTimer = 5f;
			}
		}

		internal void LateUpdate(float deltaTime, double timeAsDouble)
		{
		}

		private void SafeReceiveAndDispatch(int receivedMessages)
		{
			for (int i = 0; i < receivedMessages; i++)
			{
				IntPtr intPtr = _steamNetworkMessageReceiveBuffer[i];
				if (intPtr == IntPtr.Zero)
				{
					continue;
				}
				SteamNetworkingMessage_t message = SteamNetworkingMessage_t.FromIntPtr(intPtr);
				SteamNetworkMessage steamNetworkMessage = null;
				try
				{
					steamNetworkMessage = NetworkMessagePool.RentReceive(message, SafeRW);
					NetProfiler.TrackMessageReceived((byte)steamNetworkMessage.Type, message.m_cbSize);
					_networkMessageDispatcher.Dispatch(steamNetworkMessage);
				}
				finally
				{
					if (steamNetworkMessage != null)
					{
						NetworkMessagePool.Return(steamNetworkMessage);
					}
					SteamNetworkingMessage_t.Release(intPtr);
					_steamNetworkMessageReceiveBuffer[i] = IntPtr.Zero;
				}
			}
		}

		private unsafe void UnsafeReceiveAndDispatch(int receivedMessages)
		{
			for (int i = 0; i < receivedMessages; i++)
			{
				IntPtr intPtr = _steamNetworkMessageReceiveBuffer[i];
				if (intPtr == IntPtr.Zero)
				{
					continue;
				}
				SteamNetworkingMessage_t message = Unsafe.ReadUnaligned<SteamNetworkingMessage_t>(intPtr.ToPointer());
				SteamNetworkMessage steamNetworkMessage = null;
				try
				{
					steamNetworkMessage = NetworkMessagePool.RentReceive(message, SafeRW);
					_networkMessageDispatcher.Dispatch(steamNetworkMessage);
				}
				finally
				{
					if (steamNetworkMessage != null)
					{
						NetworkMessagePool.Return(steamNetworkMessage);
					}
					SteamNetworkingMessage_t.Release(intPtr);
					_steamNetworkMessageReceiveBuffer[i] = IntPtr.Zero;
				}
			}
		}

		private void SafeSend(SteamNetworkMessage steamNetworkMessage, int sentMessages)
		{
			byte[] buffer = steamNetworkMessage.GetBuffer();
			long length = steamNetworkMessage.GetLength();
			if (length >= int.MaxValue)
			{
				throw new InvalidOperationException();
			}
			HSteamNetConnection steamNetConnectionHandle = steamNetworkMessage.SteamNetConnectionHandle;
			int sendFlags = (int)steamNetworkMessage.SendFlags;
			GCHandle gCHandle = GCHandle.Alloc(buffer, GCHandleType.Pinned);
			try
			{
				SteamNetworkingSockets.SendMessageToConnection(steamNetConnectionHandle, gCHandle.AddrOfPinnedObject(), (uint)length, sendFlags, out var _);
			}
			finally
			{
				gCHandle.Free();
			}
			NetProfiler.TrackMessageSent((byte)steamNetworkMessage.Type, (int)length);
		}

		private void UnsafeSend(SteamNetworkMessage steamNetworkMessage, int sentMessages)
		{
		}

		internal void SendMessage<TMsg>(TMsg tMsg) where TMsg : MessageBase
		{
			if (!IsConnected || _steamNetConnectionHandle == HSteamNetConnection.Invalid)
			{
				return;
			}
			try
			{
				(MessageType messageType, MessageSendFlags messageSendFlags) messageTypeAndSendFlags = _networkMessageDispatcher.GetMessageTypeAndSendFlags(tMsg.GetType());
				MessageType item = messageTypeAndSendFlags.messageType;
				MessageSendFlags item2 = messageTypeAndSendFlags.messageSendFlags;
				SteamNetworkMessage steamNetworkMessage = NetworkMessagePool.RentSend(_remoteSteamUserId, _steamNetConnectionHandle, item, item2);
				steamNetworkMessage.Serialize(tMsg);
				_steamNetworkMessageSendQueue.Enqueue(steamNetworkMessage);
			}
			catch (Exception ex)
			{
				ModLogger.Error("[SendMessage] Failed to send " + typeof(TMsg).Name + ": " + ex.Message);
			}
		}

		private void SetState(SteamNetworkClientState steamNetworkClientState)
		{
			State = steamNetworkClientState;
		}

		[NetworkMessageHandler(MessageType.KeepAlive)]
		private void HandleKeepAlive(SteamNetworkMessage steamNetworkMessage)
		{
		}

		[NetworkMessageHandler(MessageType.HostWelcome)]
		private void HandleHostWelcome(SteamNetworkMessage steamNetworkMessage)
		{
			foreach (HostWelcomeMessage.PlayerInfo existingPlayer in steamNetworkMessage.Deserialize<HostWelcomeMessage>().ExistingPlayers)
			{
				_ = existingPlayer;
			}
		}

		[NetworkMessageHandler(MessageType.SeedSync)]
		private void HandleSeedSync(SteamNetworkMessage steamNetworkMessage)
		{
			//IL_0021: Unknown result type (might be due to invalid IL or missing references)
			//IL_002b: Expected O, but got Unknown
			SeedSyncMessage seedSyncMessage = steamNetworkMessage.Deserialize<SeedSyncMessage>();
			Random.InitState(seedSyncMessage.Seed);
			MapGenerator.seed = seedSyncMessage.Seed;
			MyRandom.random = (Random)new ConsistentRandom(seedSyncMessage.Seed);
		}

		[NetworkMessageHandler(MessageType.SpawnedObjectBatch)]
		private void HandleInteractableSpawnBatch(SteamNetworkMessage steamNetworkMessage)
		{
			SpawnedObjectBatchMessage msg = steamNetworkMessage.Deserialize<SpawnedObjectBatchMessage>();
			MatchContext.Current?.SpawnedObjects.HandleSpawnedObjectBatch(msg);
		}

		[NetworkMessageHandler(MessageType.PickupSpawned)]
		private void HandlePickupSpawn(SteamNetworkMessage steamNetworkMessage)
		{
			PickupSpawnedMessage msg = steamNetworkMessage.Deserialize<PickupSpawnedMessage>();
			MatchContext.Current?.Pickups?.HandlePickupSpawn(msg);
		}

		[NetworkMessageHandler(MessageType.Chat)]
		private void HandleChatMessage(SteamNetworkMessage steamNetworkMessage)
		{
			ChatMessage chatMessage = steamNetworkMessage.Deserialize<ChatMessage>();
			ChatWindowUi.Instance?.AddMessage(chatMessage.SenderSteamId, chatMessage.Text);
		}

		private void Reset()
		{
			CloseConnection();
			UnsubscribeFromCallbacksAndCallResults();
			ResetNetworkMessageDispatcher();
			Array.Clear(_steamNetworkMessageReceiveBuffer);
			Array.Clear(_steamNetworkMessageSendBuffer);
			Array.Clear(_steamNetworkMessageSendResults);
			_steamNetworkMessageSendQueue.Clear();
			Instance = null;
		}

		private void CloseConnection()
		{
			if (!(_steamNetConnectionHandle == HSteamNetConnection.Invalid))
			{
				SteamNetworkingSockets.CloseConnection(_steamNetConnectionHandle, 0, string.Empty, bEnableLinger: true);
			}
		}

		private void UnsubscribeFromCallbacksAndCallResults()
		{
			SteamNetworkingImpl.OnSteamNetAuthenticationStatusCurrent = (SteamNetworkingImpl.SteamNetAuthenticationStatusCurrentCallbackDelegate)Delegate.Remove(SteamNetworkingImpl.OnSteamNetAuthenticationStatusCurrent, new SteamNetworkingImpl.SteamNetAuthenticationStatusCurrentCallbackDelegate(OnSteamNetAuthenticationStatusCurrent));
			SteamNetworkingImpl.OnSteamRelayNetworkStatusCurrent = (SteamNetworkingImpl.SteamRelayNetworkStatusCurrentCallbackDelegate)Delegate.Remove(SteamNetworkingImpl.OnSteamRelayNetworkStatusCurrent, new SteamNetworkingImpl.SteamRelayNetworkStatusCurrentCallbackDelegate(OnSteamRelayNetworkStatusCurrent));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionAccepted = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionAcceptedCallbackDelegate)Delegate.Remove(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionAccepted, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionAcceptedCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionAccepted));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionClosedOrRejected = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionClosedOrRejectedCallbackDelegate)Delegate.Remove(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionClosedOrRejected, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionClosedOrRejectedCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionClosedOrRejected));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionProblem = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionProblemCallbackDelegate)Delegate.Remove(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionProblem, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionProblemCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionProblem));
		}

		private void ResetNetworkMessageDispatcher()
		{
			_networkMessageDispatcher?.Reset();
		}

		private void Dispose(bool disposing)
		{
			if (!_disposedValue)
			{
				if (disposing)
				{
					Reset();
				}
				_disposedValue = true;
			}
		}

		public void Dispose()
		{
			Dispose(disposing: true);
			GC.SuppressFinalize(this);
		}

		public async ValueTask DisposeAsync()
		{
			Dispose();
		}
	}
	internal delegate void ClientConnectedDelegate();
	internal enum SteamNetConnectionEnd
	{
		Invalid = 0,
		Generic = 1000,
		ServerShutdown = 1001,
		ClientShutdown = 1002,
		ExceptionGeneric = 2000,
		ServerError = 2001,
		ClientError = 2002
	}
	internal enum SteamNetworkLobbyState
	{
		None,
		Searching,
		Leaving,
		InvitePending,
		Joining,
		Joined
	}
	internal enum SteamNetworkLobbyType
	{
		Unknown = -1,
		Private,
		FriendsOnly,
		Public
	}
	internal enum ETier
	{
		Tier1,
		Tier2,
		Tier3
	}
	internal enum SteamNetworkMode
	{
		None,
		Server,
		Client
	}
	internal enum SteamNetworkServerState
	{
		None,
		ReadyToListen,
		Listening,
		Error
	}
	internal enum SteamNetworkClientState
	{
		None,
		ReadyToConnect,
		Connecting,
		Connected,
		Error
	}
	internal enum ChatType : byte
	{
		Text,
		Command
	}
	internal sealed class SteamNetworkLobby
	{
		internal delegate void ServerReadyChangedDelegate(bool serverReady);

		internal delegate void OnMemberAddedDelegate(SteamNetworkLobby steamNetworkLobby, SteamNetworkLobbyMember member);

		internal delegate void OnMemberRemovedDelegate(SteamNetworkLobby steamNetworkLobby, SteamNetworkLobbyMember member);

		internal delegate void OnUpdateLobbyDataDelegate(SteamNetworkLobby steamNetworkLobby);

		internal delegate void OnUpdateMemberDataDelegate(SteamNetworkLobby steamNetworkLobby, SteamNetworkLobbyMember member);

		private const string LobbyDataNameKey = "name";

		private const string LobbyDataMapKey = "map";

		private const string LobbyDataTierKey = "tier";

		private const string LobbyDataSeedKey = "seed";

		private const string LobbyDataChallengeKey = "challenge";

		private const string LobbyDataServerReadyKey = "serverReady";

		private const string LobbyDataNetworkLobbyUiTypeKey = "nlui";

		private const string LobbyMemberDataReadyKey = "ready";

		private const string LobbyMemberDataCharacterKey = "character";

		private const string LobbyMemberDataSkinTypeKey = "skinType";

		internal static SteamNetworkLobby Instance;

		private readonly object _syncRoot = new object();

		private readonly bool _created;

		private bool _firstLobbyUpdate;

		private List<SteamNetworkLobbyMember> _members;

		internal ServerReadyChangedDelegate OnServerReadyChanged;

		internal OnMemberAddedDelegate OnMemberAdded;

		internal OnMemberRemovedDelegate OnMemberRemoved;

		internal OnUpdateLobbyDataDelegate OnUpdateLobbyData;

		internal OnUpdateMemberDataDelegate OnUpdateMemberData;

		internal CSteamID LobbyId { get; private set; }

		internal CSteamID LobbyOwnerUserId { get; private set; }

		internal SteamNetworkLobbyType LobbyType { get; set; } = SteamNetworkLobbyType.Unknown;

		internal IReadOnlyList<SteamNetworkLobbyMember> Members => _members;

		internal int MemberCount => _members.Count;

		internal int MaxMembers { get; private set; }

		internal string Name { get; private set; }

		internal EMap Map { get; private set; }

		internal int Tier { get; private set; }

		internal int Seed { get; private set; }

		internal string ChallengeName { get; private set; }

		internal bool ServerReady { get; private set; }

		internal NetworkLobbyUiType NetworkLobbyUiType { get; private set; }

		internal SteamNetworkLobby(CSteamID steamLobbyId, bool created)
		{
			if (Instance != null)
			{
				throw new InvalidOperationException("Instance");
			}
			if (steamLobbyId == CSteamID.Nil)
			{
				throw new ArgumentNullException("steamLobbyId");
			}
			Instance = this;
			_created = created;
			LobbyId = steamLobbyId;
			Setup();
		}

		private void Setup()
		{
			_firstLobbyUpdate = false;
			lock (_syncRoot)
			{
				_members = new List<SteamNetworkLobbyMember>(MaxMembers);
			}
			SubscribeToCallbacksAndCallResults();
		}

		private void SubscribeToCallbacksAndCallResults()
		{
			SteamMatchmakingImpl.OnLobbyChatUpdateMemberEntered = (SteamMatchmakingImpl.LobbyChatUpdateMemberEnteredCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyChatUpdateMemberEntered, new SteamMatchmakingImpl.LobbyChatUpdateMemberEnteredCallbackDelegate(OnLobbyChatUpdateMemberEntered));
			SteamMatchmakingImpl.OnLobbyChatUpdateMemberLeft = (SteamMatchmakingImpl.LobbyChatUpdateMemberLeftCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyChatUpdateMemberLeft, new SteamMatchmakingImpl.LobbyChatUpdateMemberLeftCallbackDelegate(OnLobbyChatUpdateMemberLeft));
			SteamMatchmakingImpl.OnLobbyChatUpdateMemberDisconnected = (SteamMatchmakingImpl.LobbyChatUpdateMemberDisconnectedCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyChatUpdateMemberDisconnected, new SteamMatchmakingImpl.LobbyChatUpdateMemberDisconnectedCallbackDelegate(OnLobbyChatUpdateMemberDisconnected));
			SteamMatchmakingImpl.OnLobbyChatUpdateMemberKicked = (SteamMatchmakingImpl.LobbyChatUpdateMemberKickedCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyChatUpdateMemberKicked, new SteamMatchmakingImpl.LobbyChatUpdateMemberKickedCallbackDelegate(OnLobbyChatUpdateMemberKicked));
			SteamMatchmakingImpl.OnLobbyChatUpdateMemberBanned = (SteamMatchmakingImpl.LobbyChatUpdateMemberBannedCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyChatUpdateMemberBanned, new SteamMatchmakingImpl.LobbyChatUpdateMemberBannedCallbackDelegate(OnLobbyChatUpdateMemberBanned));
			SteamMatchmakingImpl.OnLobbyDataUpdateLobby = (SteamMatchmakingImpl.LobbyDataUpdateLobbyCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyDataUpdateLobby, new SteamMatchmakingImpl.LobbyDataUpdateLobbyCallbackDelegate(OnLobbyDataUpdateLobby));
			SteamMatchmakingImpl.OnLobbyDataUpdateMember = (SteamMatchmakingImpl.LobbyDataUpdateMemberCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyDataUpdateMember, new SteamMatchmakingImpl.LobbyDataUpdateMemberCallbackDelegate(OnLobbyDataUpdateMember));
			SteamMatchmakingImpl.OnLobbyChatMsg = (SteamMatchmakingImpl.LobbyChatMsgCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyChatMsg, new SteamMatchmakingImpl.LobbyChatMsgCallbackDelegate(OnLobbyChatMsg));
		}

		internal bool OwnedByUs()
		{
			return LobbyOwnerUserId == SteamUser.GetSteamID();
		}

		private bool IsThisLobby(CSteamID steamLobbyId)
		{
			if (LobbyId != CSteamID.Nil && steamLobbyId != CSteamID.Nil)
			{
				return LobbyId == steamLobbyId;
			}
			return false;
		}

		internal bool HasMember(CSteamID steamUserId)
		{
			return GetMember(steamUserId) != null;
		}

		internal SteamNetworkLobbyMember GetMember(CSteamID steamUserId)
		{
			if (steamUserId == CSteamID.Nil)
			{
				throw new ArgumentNullException("steamUserId");
			}
			lock (_syncRoot)
			{
				return _members.FirstOrDefault((SteamNetworkLobbyMember snlm) => snlm.UserId == steamUserId);
			}
		}

		private void AddMember(CSteamID steamUserId)
		{
			if (steamUserId == CSteamID.Nil)
			{
				throw new ArgumentNullException("steamUserId");
			}
			if (HasMember(steamUserId))
			{
				throw new ArgumentOutOfRangeException("steamUserId");
			}
			SteamNetworkLobbyMember steamNetworkLobbyMember = new SteamNetworkLobbyMember(LobbyId, steamUserId);
			lock (_syncRoot)
			{
				_members.Add(steamNetworkLobbyMember);
				OnMemberAdded?.Invoke(this, steamNetworkLobbyMember);
			}
		}

		private void RemoveMember(CSteamID steamUserId)
		{
			if (steamUserId == CSteamID.Nil)
			{
				throw new ArgumentNullException("steamUserId");
			}
			lock (_syncRoot)
			{
				SteamNetworkLobbyMember steamNetworkLobbyMember = _members.FirstOrDefault((SteamNetworkLobbyMember snlm) => snlm.UserId == steamUserId);
				if (steamNetworkLobbyMember != null && _members.Remove(steamNetworkLobbyMember))
				{
					OnMemberRemoved?.Invoke(this, steamNetworkLobbyMember);
				}
			}
		}

		private void OnLobbyChatUpdateMemberEntered(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator)
		{
			if (IsThisLobby(steamLobbyId) && !(steamUserIdRecipient == CSteamID.Nil))
			{
				AddMember(steamUserIdRecipient);
			}
		}

		private void OnLobbyChatUpdateMemberLeft(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator)
		{
			if (IsThisLobby(steamLobbyId) && !(steamUserIdRecipient == CSteamID.Nil))
			{
				RemoveMember(steamUserIdRecipient);
			}
		}

		private void OnLobbyChatUpdateMemberDisconnected(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator)
		{
			if (IsThisLobby(steamLobbyId) && !(steamUserIdRecipient == CSteamID.Nil))
			{
				RemoveMember(steamUserIdRecipient);
			}
		}

		private void OnLobbyChatUpdateMemberKicked(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator)
		{
			if (IsThisLobby(steamLobbyId) && !(steamUserIdRecipient == CSteamID.Nil))
			{
				RemoveMember(steamUserIdRecipient);
			}
		}

		private void OnLobbyChatUpdateMemberBanned(CSteamID steamLobbyId, CSteamID steamUserIdRecipient, CSteamID steamUserIdInitiator)
		{
			if (IsThisLobby(steamLobbyId) && !(steamUserIdRecipient == CSteamID.Nil))
			{
				RemoveMember(steamUserIdRecipient);
			}
		}

		private void OnLobbyDataUpdateLobby(CSteamID steamLobbyId)
		{
			if (!IsThisLobby(steamLobbyId))
			{
				return;
			}
			if (!_firstLobbyUpdate)
			{
				MaxMembers = SteamMatchmaking.GetLobbyMemberLimit(LobbyId);
				LobbyOwnerUserId = SteamMatchmaking.GetLobbyOwner(LobbyId);
				if (LobbyOwnerUserId == CSteamID.Nil)
				{
					throw new NullReferenceException("LobbyOwnerUserId");
				}
				int numLobbyMembers = SteamMatchmaking.GetNumLobbyMembers(LobbyId);
				for (int i = 0; i < numLobbyMembers; i++)
				{
					CSteamID lobbyMemberByIndex = SteamMatchmaking.GetLobbyMemberByIndex(LobbyId, i);
					if (lobbyMemberByIndex == CSteamID.Nil)
					{
						throw new NullReferenceException("lobbyMemberUserId");
					}
					AddMember(lobbyMemberByIndex);
					UpdateMemberData(lobbyMemberByIndex);
				}
				if (_created)
				{
					SetLobbyName();
					int seed = (int)(((ulong)DateTime.UtcNow.Ticks ^ SteamUser.GetSteamID().m_SteamID) & 0x7FFFFFFF);
					SetSeed(seed);
					SteamNetworkManager.CreateAndStartServer();
					if (SteamNetworkServer.Instance.IsListening)
					{
						SetServerReady(serverReady: true);
					}
				}
				_firstLobbyUpdate = true;
			}
			UpdateLobbyData();
		}

		internal void SetLobbyName(string name = "")
		{
			if (!(LobbyOwnerUserId != SteamUser.GetSteamID()))
			{
				SteamMatchmaking.SetLobbyData(LobbyId, "name", string.IsNullOrWhiteSpace(name) ? (SteamFriends.GetPersonaName() + "'s Lobby") : name);
			}
		}

		private void UpdateLobbyData()
		{
			//IL_0053: Unknown result type (might be due to invalid IL or missing references)
			//IL_0058: Unknown result type (might be due to invalid IL or missing references)
			//IL_005d: Unknown result type (might be due to invalid IL or missing references)
			string lobbyData = SteamMatchmaking.GetLobbyData(LobbyId, "name");
			if (!string.IsNullOrWhiteSpace(lobbyData) && !lobbyData.Equals(Name))
			{
				Name = lobbyData;
			}
			string lobbyData2 = SteamMatchmaking.GetLobbyData(LobbyId, "map");
			if (!string.IsNullOrWhiteSpace(lobbyData2) && Enum.TryParse<EMap>(lobbyData2, ignoreCase: false, out EMap result) && Map != result)
			{
				Map = result;
			}
			string lobbyData3 = SteamMatchmaking.GetLobbyData(LobbyId, "tier");
			if (!string.IsNullOrWhiteSpace(lobbyData3) && int.TryParse(lobbyData3, out var result2) && Tier != result2)
			{
				Tier = result2;
			}
			string lobbyData4 = SteamMatchmaking.GetLobbyData(LobbyId, "seed");
			if (!string.IsNullOrWhiteSpace(lobbyData4) && int.TryParse(lobbyData4, out var result3) && Seed != result3)
			{
				Seed = result3;
			}
			string lobbyData5 = SteamMatchmaking.GetLobbyData(LobbyId, "challenge");
			if (!string.IsNullOrWhiteSpace(lobbyData5))
			{
				foreach (ChallengeData item in Resources.FindObjectsOfTypeAll<ChallengeData>())
				{
					if (((Object)item).name == lobbyData5)
					{
						ChallengeName = ((Object)item).name;
						break;
					}
				}
			}
			CSteamID lobbyOwner = SteamMatchmaking.GetLobbyOwner(LobbyId);
			if (lobbyOwner != CSteamID.Nil && lobbyOwner != LobbyOwnerUserId)
			{
				_ = LobbyOwnerUserId;
				LobbyOwnerUserId = lobbyOwner;
			}
			string lobbyData6 = SteamMatchmaking.GetLobbyData(LobbyId, "serverReady");
			if (!string.IsNullOrWhiteSpace(lobbyData6) && bool.TryParse(lobbyData6, out var result4) && ServerReady != result4)
			{
				ServerReady = result4;
				if (ServerReady && !_created)
				{
					SteamNetworkManager.CreateClientAndConnect(LobbyOwnerUserId, OnClientConnected);
				}
				OnServerReadyChanged?.Invoke(ServerReady);
			}
			string lobbyData7 = SteamMatchmaking.GetLobbyData(LobbyId, "nlui");
			if (!string.IsNullOrWhiteSpace(lobbyData7) && Enum.TryParse<NetworkLobbyUiType>(lobbyData7, out var result5) && NetworkLobbyUiType != result5)
			{
				NetworkLobbyUiType = result5;
			}
			OnUpdateLobbyData?.Invoke(this);
		}

		private void OnClientConnected()
		{
			_ = SteamNetworkClient.Instance.IsConnected;
		}

		private void OnLobbyDataUpdateMember(CSteamID steamLobbyId, CSteamID steamMemberId)
		{
			if (IsThisLobby(steamLobbyId) && !(steamMemberId == CSteamID.Nil))
			{
				UpdateMemberData(steamMemberId);
			}
		}

		private void UpdateMemberData(CSteamID steamMemberId)
		{
			//IL_0071: Unknown result type (might be due to invalid IL or missing references)
			//IL_0076: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ae: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b3: Unknown result type (might be due to invalid IL or missing references)
			//IL_007b: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b8: Unknown result type (might be due to invalid IL or missing references)
			if (!HasMember(steamMemberId))
			{
				return;
			}
			SteamNetworkLobbyMember member = GetMember(steamMemberId);
			if (member != null)
			{
				string lobbyMemberData = SteamMatchmaking.GetLobbyMemberData(LobbyId, steamMemberId, "ready");
				if (!string.IsNullOrWhiteSpace(lobbyMemberData) && bool.TryParse(lobbyMemberData, out var result) && member.IsReady != result)
				{
					member.IsReady = result;
				}
				string lobbyMemberData2 = SteamMatchmaking.GetLobbyMemberData(LobbyId, steamMemberId, "character");
				if (!string.IsNullOrWhiteSpace(lobbyMemberData2) && Enum.TryParse<ECharacter>(lobbyMemberData2, out ECharacter result2) && member.Character != result2)
				{
					member.Character = result2;
					member.HasSelectedCharacter = true;
				}
				string lobbyMemberData3 = SteamMatchmaking.GetLobbyMemberData(LobbyId, steamMemberId, "skinType");
				if (!string.IsNullOrWhiteSpace(lobbyMemberData3) && Enum.TryParse<ESkinType>(lobbyMemberData3, out ESkinType result3) && member.SkinType != result3)
				{
					member.SkinType = result3;
				}
				OnUpdateMemberData?.Invoke(this, member);
			}
		}

		private void OnLobbyChatMsg(CSteamID steamLobbyId, CSteamID steamUserId, string message)
		{
			if (!IsThisLobby(steamLobbyId) || steamUserId == CSteamID.Nil || !HasMember(steamUserId) || !message.StartsWith('/'))
			{
				return;
			}
			string[] array = message.Substring(1).Split(' ', 2);
			if (array.Length != 2)
			{
				return;
			}
			string text = array[0];
			string text2 = array[1];
			if (!string.IsNullOrWhiteSpace(text))
			{
				ulong result2;
				if (text.Equals("kick", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(text2) && ulong.TryParse(text2, out var result))
				{
					CSteamID kickedSteamId = new CSteamID(result);
					OnLobbyMemberKickRequested(steamUserId, kickedSteamId);
				}
				else if (text.Equals("ban", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(text2) && ulong.TryParse(text2, out result2))
				{
					CSteamID bannedSteamId = new CSteamID(result2);
					OnLobbyMemberBanRequested(steamUserId, bannedSteamId);
				}
			}
		}

		private void OnLobbyMemberKickRequested(CSteamID initiatorSteamUserId, CSteamID kickedSteamId)
		{
			if (!(initiatorSteamUserId != LobbyOwnerUserId) && !(kickedSteamId != SteamManager.Instance.CurrentUserId))
			{
				SteamNetworkLobbyManager.LeaveLobby();
			}
		}

		private void OnLobbyMemberBanRequested(CSteamID initiatorSteamUserId, CSteamID bannedSteamId)
		{
			if (!(initiatorSteamUserId != LobbyOwnerUserId) && !(bannedSteamId != SteamManager.Instance.CurrentUserId))
			{
				SteamNetworkLobbyManager.LeaveLobby();
			}
		}

		internal void SetSeed(int seed)
		{
			if (!(LobbyOwnerUserId != SteamUser.GetSteamID()))
			{
				SteamMatchmaking.SetLobbyData(LobbyId, "seed", seed.ToString());
			}
		}

		internal unsafe void SetMap(EMap eMap = (EMap)0)
		{
			if (!(LobbyOwnerUserId != SteamUser.GetSteamID()))
			{
				SteamMatchmaking.SetLobbyData(LobbyId, "map", ((object)(*(EMap*)(&eMap))/*cast due to .constrained prefix*/).ToString());
			}
		}

		internal void SetTier(int tier = 0)
		{
			if (!(LobbyOwnerUserId != SteamUser.GetSteamID()) && tier >= 0 && tier <= 2)
			{
				SteamMatchmaking.SetLobbyData(LobbyId, "tier", tier.ToString());
			}
		}

		internal void SetTier(ETier eTier = ETier.Tier1)
		{
			SetTier((int)eTier);
		}

		internal void SetChallenge(ChallengeData challengeData)
		{
			if (!(LobbyOwnerUserId != SteamUser.GetSteamID()))
			{
				string pchValue = (((Object)(object)challengeData != (Object)null) ? ((Object)challengeData).name : "");
				SteamMatchmaking.SetLobbyData(LobbyId, "challenge", pchValue);
			}
		}

		internal void SetServerReady(bool serverReady)
		{
			if (!(LobbyOwnerUserId != SteamUser.GetSteamID()))
			{
				SteamMatchmaking.SetLobbyData(LobbyId, "serverReady", serverReady.ToString());
			}
		}

		internal void SetNetworkLobbyUiType(NetworkLobbyUiType networkLobbyUiType)
		{
			if (!(LobbyOwnerUserId != SteamUser.GetSteamID()))
			{
				SteamMatchmaking.SetLobbyData(LobbyId, "nlui", networkLobbyUiType.ToString());
			}
		}

		internal void MemberSetReady(bool isReady)
		{
			SteamMatchmaking.SetLobbyMemberData(LobbyId, "ready", isReady.ToString());
		}

		internal unsafe void MemberSetCharacter(ECharacter eCharacter = (ECharacter)0)
		{
			SteamMatchmaking.SetLobbyMemberData(LobbyId, "character", ((object)(*(ECharacter*)(&eCharacter))/*cast due to .constrained prefix*/).ToString());
		}

		internal unsafe void MemberSetSkinType(ESkinType eSkinType = (ESkinType)0)
		{
			SteamMatchmaking.SetLobbyMemberData(LobbyId, "skinType", ((object)(*(ESkinType*)(&eSkinType))/*cast due to .constrained prefix*/).ToString());
		}

		internal void MemberKick(CSteamID steamUserId)
		{
			if (!(LobbyOwnerUserId != SteamUser.GetSteamID()) && !(steamUserId == CSteamID.Nil) && HasMember(steamUserId))
			{
				string s = $"/kick {steamUserId.m_SteamID}";
				byte[] bytes = Encoding.UTF8.GetBytes(s);
				SteamMatchmaking.SendLobbyChatMsg(LobbyId, bytes, bytes.Length);
			}
		}

		internal void MemberBan(CSteamID steamUserId)
		{
			if (!(LobbyOwnerUserId != SteamUser.GetSteamID()) && !(steamUserId == CSteamID.Nil) && HasMember(steamUserId))
			{
				string s = $"/ban {steamUserId.m_SteamID}";
				byte[] bytes = Encoding.UTF8.GetBytes(s);
				SteamMatchmaking.SendLobbyChatMsg(LobbyId, bytes, bytes.Length);
			}
		}

		internal bool AreAllMembersReady()
		{
			lock (_syncRoot)
			{
				return _members.All((SteamNetworkLobbyMember m) => m.IsReady);
			}
		}

		internal void Reset()
		{
			if (_created)
			{
				SteamNetworkManager.DestroyServer();
			}
			else
			{
				SteamNetworkManager.DestroyClient();
			}
			UnsubscribeFromCallbacksAndCallResults();
			lock (_syncRoot)
			{
				_members?.Clear();
			}
			LobbyId = CSteamID.Nil;
			LobbyOwnerUserId = CSteamID.Nil;
			Instance = null;
		}

		private void UnsubscribeFromCallbacksAndCallResults()
		{
			SteamMatchmakingImpl.OnLobbyChatUpdateMemberEntered = (SteamMatchmakingImpl.LobbyChatUpdateMemberEnteredCallbackDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyChatUpdateMemberEntered, new SteamMatchmakingImpl.LobbyChatUpdateMemberEnteredCallbackDelegate(OnLobbyChatUpdateMemberEntered));
			SteamMatchmakingImpl.OnLobbyChatUpdateMemberLeft = (SteamMatchmakingImpl.LobbyChatUpdateMemberLeftCallbackDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyChatUpdateMemberLeft, new SteamMatchmakingImpl.LobbyChatUpdateMemberLeftCallbackDelegate(OnLobbyChatUpdateMemberLeft));
			SteamMatchmakingImpl.OnLobbyChatUpdateMemberDisconnected = (SteamMatchmakingImpl.LobbyChatUpdateMemberDisconnectedCallbackDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyChatUpdateMemberDisconnected, new SteamMatchmakingImpl.LobbyChatUpdateMemberDisconnectedCallbackDelegate(OnLobbyChatUpdateMemberDisconnected));
			SteamMatchmakingImpl.OnLobbyChatUpdateMemberKicked = (SteamMatchmakingImpl.LobbyChatUpdateMemberKickedCallbackDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyChatUpdateMemberKicked, new SteamMatchmakingImpl.LobbyChatUpdateMemberKickedCallbackDelegate(OnLobbyChatUpdateMemberKicked));
			SteamMatchmakingImpl.OnLobbyChatUpdateMemberBanned = (SteamMatchmakingImpl.LobbyChatUpdateMemberBannedCallbackDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyChatUpdateMemberBanned, new SteamMatchmakingImpl.LobbyChatUpdateMemberBannedCallbackDelegate(OnLobbyChatUpdateMemberBanned));
			SteamMatchmakingImpl.OnLobbyDataUpdateLobby = (SteamMatchmakingImpl.LobbyDataUpdateLobbyCallbackDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyDataUpdateLobby, new SteamMatchmakingImpl.LobbyDataUpdateLobbyCallbackDelegate(OnLobbyDataUpdateLobby));
			SteamMatchmakingImpl.OnLobbyDataUpdateMember = (SteamMatchmakingImpl.LobbyDataUpdateMemberCallbackDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyDataUpdateMember, new SteamMatchmakingImpl.LobbyDataUpdateMemberCallbackDelegate(OnLobbyDataUpdateMember));
			SteamMatchmakingImpl.OnLobbyChatMsg = (SteamMatchmakingImpl.LobbyChatMsgCallbackDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyChatMsg, new SteamMatchmakingImpl.LobbyChatMsgCallbackDelegate(OnLobbyChatMsg));
		}
	}
	internal static class SteamNetworkLobbyManager
	{
		private const int CMaxPlayers = 4;

		private const float LOBBY_SEARCH_TIMEOUT = 10f;

		private const float LOBBY_JOIN_TIMEOUT = 15f;

		internal static OnLobbyEnteredDelegate OnLobbyEntered;

		internal static OnLobbyLeftDelegate OnLobbyLeft;

		private static object _searchTimeoutCoroutine;

		private static object _joinTimeoutCoroutine;

		internal static int MaxPlayers => Preferences.MaxPlayers.Value;

		internal static SteamNetworkLobbyState State { get; private set; }

		internal static Queue<SteamNetworkLobbyType> LobbyTypeQueue { get; private set; }

		static SteamNetworkLobbyManager()
		{
			LobbyTypeQueue = new Queue<SteamNetworkLobbyType>();
			SubscribeToCallbacksAndCallResults();
		}

		private static void SubscribeToCallbacksAndCallResults()
		{
			SteamMatchmakingImpl.OnLobbyCreatedOK = (SteamMatchmakingImpl.LobbyCreatedOKCallResultDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyCreatedOK, new SteamMatchmakingImpl.LobbyCreatedOKCallResultDelegate(OnLobbyCreatedOK));
			SteamMatchmakingImpl.OnLobbyCreatedFail = (SteamMatchmakingImpl.LobbyCreatedFailCallResultDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyCreatedFail, new SteamMatchmakingImpl.LobbyCreatedFailCallResultDelegate(OnLobbyCreatedFail));
			SteamMatchmakingImpl.OnLobbyCreatedAccessDenied = (SteamMatchmakingImpl.LobbyCreatedAccessDeniedCallResultDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyCreatedAccessDenied, new SteamMatchmakingImpl.LobbyCreatedAccessDeniedCallResultDelegate(OnLobbyCreatedFail));
			SteamMatchmakingImpl.OnLobbyCreatedLimitExceeded = (SteamMatchmakingImpl.LobbyCreatedLimitExceededCallResultDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyCreatedLimitExceeded, new SteamMatchmakingImpl.LobbyCreatedLimitExceededCallResultDelegate(OnLobbyCreatedFail));
			SteamMatchmakingImpl.OnLobbyCreatedNoConnection = (SteamMatchmakingImpl.LobbyCreatedNoConnectionCallResultDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyCreatedNoConnection, new SteamMatchmakingImpl.LobbyCreatedNoConnectionCallResultDelegate(OnLobbyCreatedFail));
			SteamMatchmakingImpl.OnLobbyCreatedTimeout = (SteamMatchmakingImpl.LobbyCreatedTimeoutCallResultDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyCreatedTimeout, new SteamMatchmakingImpl.LobbyCreatedTimeoutCallResultDelegate(OnLobbyCreatedFail));
			SteamMatchmakingImpl.OnLobbyEnterInitiatedSuccess = (SteamMatchmakingImpl.LobbyEnterSuccessCallResultDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyEnterInitiatedSuccess, new SteamMatchmakingImpl.LobbyEnterSuccessCallResultDelegate(OnLobbyEnterInitiatedSuccess));
			SteamMatchmakingImpl.OnLobbyEnterInitiatedError = (SteamMatchmakingImpl.LobbyEnterErrorCallResultDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyEnterInitiatedError, new SteamMatchmakingImpl.LobbyEnterErrorCallResultDelegate(OnLobbyEnterInitiatedError));
			SteamMatchmakingImpl.OnLobbyEnterReceivedSuccess = (SteamMatchmakingImpl.LobbyEnterSuccessCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyEnterReceivedSuccess, new SteamMatchmakingImpl.LobbyEnterSuccessCallbackDelegate(OnLobbyEnterReceivedSuccess));
			SteamMatchmakingImpl.OnLobbyEnterReceivedError = (SteamMatchmakingImpl.LobbyEnterErrorCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyEnterReceivedError, new SteamMatchmakingImpl.LobbyEnterErrorCallbackDelegate(OnLobbyEnterReceivedError));
			SteamMatchmakingImpl.OnLobbyInvite = (SteamMatchmakingImpl.LobbyInviteCallbackDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyInvite, new SteamMatchmakingImpl.LobbyInviteCallbackDelegate(OnLobbyInvite));
			SteamFriendsImpl.OnGameLobbyJoinRequested = (SteamFriendsImpl.GameLobbyJoinRequestedCallbackDelegate)Delegate.Combine(SteamFriendsImpl.OnGameLobbyJoinRequested, new SteamFriendsImpl.GameLobbyJoinRequestedCallbackDelegate(OnGameLobbyJoinRequested));
			SteamFriendsImpl.OnGameRichPresenceJoinRequested = (SteamFriendsImpl.GameRichPresenceJoinRequestedCallbackDelegate)Delegate.Combine(SteamFriendsImpl.OnGameRichPresenceJoinRequested, new SteamFriendsImpl.GameRichPresenceJoinRequestedCallbackDelegate(OnGameRichPresenceJoinRequested));
			SteamMatchmakingImpl.OnLobbyLeave = (SteamMatchmakingImpl.LobbyLeaveDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyLeave, new SteamMatchmakingImpl.LobbyLeaveDelegate(OnLobbyLeave));
			SteamMatchmakingImpl.OnLobbyMatchList = (SteamMatchmakingImpl.LobbyMatchListCallResultDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyMatchList, new SteamMatchmakingImpl.LobbyMatchListCallResultDelegate(OnLobbyMatchList));
		}

		private static void OnLobbyCreatedOK(CSteamID steamLobbyId)
		{
			if (SteamManager.Instance.Lobby != null)
			{
				LeaveLobby();
			}
			SteamManager.Instance.Lobby = new SteamNetworkLobby(steamLobbyId, created: true)
			{
				LobbyType = LobbyTypeQueue.Dequeue()
			};
			SetState(SteamNetworkLobbyState.Joined);
			MatchContext.StartNewMatch();
			MatchContext.Current?.GameState.TransitionTo(GameLifecycleState.InLobby);
			OnLobbyEntered?.Invoke(SteamManager.Instance.Lobby);
		}

		private static void OnLobbyCreatedFail()
		{
			ModLogger.Error("[OnLobbyCreatedFail] Failed to create lobby!");
			SetState(SteamNetworkLobbyState.None);
			LobbyTypeQueue.Dequeue();
		}

		private static void OnLobbyEnterInitiatedSuccess(CSteamID steamLobbyId, bool lobbyLocked)
		{
			if (SteamManager.Instance.Lobby != null)
			{
				LeaveLobby();
			}
			if (_joinTimeoutCoroutine != null)
			{
				CoroutineRunner.Stop(_joinTimeoutCoroutine);
				_joinTimeoutCoroutine = null;
			}
			SteamManager.Instance.Lobby = new SteamNetworkLobby(steamLobbyId, created: false);
			SetState(SteamNetworkLobbyState.Joined);
			MatchContext.StartNewMatch();
			MatchContext.Current?.GameState.TransitionTo(GameLifecycleState.InLobby);
			OnLobbyEntered?.Invoke(SteamManager.Instance.Lobby);
		}

		private static void OnLobbyEnterInitiatedError(CSteamID steamLobbyId, bool lobbyLocked)
		{
			ModLogger.Error("[OnLobbyEnterInitiatedError] Failed to join lobby!");
			if (_joinTimeoutCoroutine != null)
			{
				CoroutineRunner.Stop(_joinTimeoutCoroutine);
				_joinTimeoutCoroutine = null;
			}
			SetState(SteamNetworkLobbyState.None);
		}

		private static void OnLobbyEnterReceivedSuccess(CSteamID steamLobbyId, bool lobbyLocked)
		{
			SetState(SteamNetworkLobbyState.Joined);
		}

		private static void OnLobbyEnterReceivedError(CSteamID steamLobbyId, bool lobbyLocked)
		{
			ModLogger.Error("[OnLobbyEnterReceivedError] Failed to join (our own) lobby!");
			SetState(SteamNetworkLobbyState.None);
		}

		private static void OnLobbyInvite(CSteamID steamUserIdInviter, CSteamID steamLobbyId, CSteamID steamGameId)
		{
			if (!(steamUserIdInviter == CSteamID.Nil) && !(steamLobbyId == CSteamID.Nil))
			{
				SetState(SteamNetworkLobbyState.InvitePending);
			}
		}

		private static void OnGameLobbyJoinRequested(CSteamID steamLobbyId, CSteamID steamUserId)
		{
			if (!(steamLobbyId == CSteamID.Nil) && !(steamUserId == CSteamID.Nil))
			{
				if (SteamManager.Instance.Lobby != null)
				{
					LeaveLobby();
				}
				JoinLobby(steamLobbyId);
			}
		}

		private static void OnGameRichPresenceJoinRequested(CSteamID steamUserId, string connect)
		{
			if (steamUserId == CSteamID.Nil || string.IsNullOrWhiteSpace(connect))
			{
				return;
			}
			string[] array = connect.Split(' ');
			if (array == null || array.Length != 2)
			{
				return;
			}
			_ = array[0];
			if (!ulong.TryParse(array[1], out var result))
			{
				return;
			}
			CSteamID cSteamID = new CSteamID(result);
			if (!(cSteamID == CSteamID.Nil))
			{
				if (SteamManager.Instance.Lobby != null)
				{
					LeaveLobby();
				}
				JoinLobby(cSteamID);
			}
		}

		private static void OnLobbyLeave(CSteamID steamLobbyId)
		{
			SteamNetworkLobby lobby = SteamManager.Instance.Lobby;
			if (lobby != null)
			{
				MatchContext.EndMatch();
				OnLobbyLeft?.Invoke(lobby);
				lobby.Reset();
			}
			SteamManager.Instance.Lobby = null;
			SetState(SteamNetworkLobbyState.None);
		}

		internal static void CreateLobby(SteamNetworkLobbyType lobbyType = SteamNetworkLobbyType.Public, int maxPlayers = 4)
		{
			LobbyTypeQueue.Enqueue(lobbyType);
			SteamMatchmakingImpl.SetCallResult<LobbyCreated_t>(SteamMatchmaking.CreateLobby((ELobbyType)lobbyType, maxPlayers));
			SetState(SteamNetworkLobbyState.Joining);
		}

		internal static void FindLobby()
		{
			SetState(SteamNetworkLobbyState.Searching);
			SteamMatchmaking.AddRequestLobbyListFilterSlotsAvailable(1);
			SteamMatchmaking.AddRequestLobbyListDistanceFilter(ELobbyDistanceFilter.k_ELobbyDistanceFilterWorldwide);
			SteamMatchmakingImpl.SetCallResult<LobbyMatchList_t>(SteamMatchmaking.RequestLobbyList());
			if (_searchTimeoutCoroutine != null)
			{
				CoroutineRunner.Stop(_searchTimeoutCoroutine);
			}
			_searchTimeoutCoroutine = CoroutineRunner.Start(LobbySearchTimeout());
		}

		private static void OnLobbyMatchList(int count, bool ioFailure)
		{
			if (State != SteamNetworkLobbyState.Searching)
			{
				return;
			}
			if (_searchTimeoutCoroutine != null)
			{
				CoroutineRunner.Stop(_searchTimeoutCoroutine);
				_searchTimeoutCoroutine = null;
			}
			if (ioFailure)
			{
				ModLogger.Error("[OnLobbyMatchList] IO Failure while searching.");
				SetState(SteamNetworkLobbyState.None);
				return;
			}
			CSteamID steamID = SteamUser.GetSteamID();
			for (int i = 0; i < count; i++)
			{
				CSteamID lobbyByIndex = SteamMatchmaking.GetLobbyByIndex(i);
				if (SteamMatchmaking.GetLobbyOwner(lobbyByIndex) != steamID)
				{
					JoinLobby(lobbyByIndex);
					return;
				}
			}
			SetState(SteamNetworkLobbyState.None);
			CreateLobby();
		}

		private static IEnumerator LobbySearchTimeout()
		{
			for (float elapsed = 0f; elapsed < 10f; elapsed += Time.unscaledDeltaTime)
			{
				yield return null;
			}
			if (State == SteamNetworkLobbyState.Searching)
			{
				SetState(SteamNetworkLobbyState.None);
			}
			_searchTimeoutCoroutine = null;
		}

		internal static void JoinLobby(CSteamID steamLobbyId)
		{
			if (steamLobbyId == CSteamID.Nil)
			{
				throw new ArgumentNullException("steamLobbyId");
			}
			SteamMatchmakingImpl.SetCallResult<LobbyEnter_t>(SteamMatchmaking.JoinLobby(steamLobbyId));
			SetState(SteamNetworkLobbyState.Joining);
			if (_joinTimeoutCoroutine != null)
			{
				CoroutineRunner.Stop(_joinTimeoutCoroutine);
			}
			_joinTimeoutCoroutine = CoroutineRunner.Start(LobbyJoinTimeout(steamLobbyId));
		}

		private static IEnumerator LobbyJoinTimeout(CSteamID attemptedLobbyId)
		{
			for (float elapsed = 0f; elapsed < 15f; elapsed += Time.unscaledDeltaTime)
			{
				yield return null;
			}
			if (State == SteamNetworkLobbyState.Joining)
			{
				SetState(SteamNetworkLobbyState.None);
			}
			_joinTimeoutCoroutine = null;
		}

		internal static void LeaveLobby()
		{
			SteamNetworkLobby lobby = SteamManager.Instance.Lobby;
			if (lobby != null)
			{
				CSteamID lobbyId = lobby.LobbyId;
				if (lobbyId == CSteamID.Nil)
				{
					throw new NullReferenceException("currentLobbyId");
				}
				SteamMatchmaking.LeaveLobby(lobbyId);
				SetState(SteamNetworkLobbyState.Leaving);
				SteamMatchmakingImpl.OnLobbyLeaveManual(lobbyId);
			}
		}

		internal static void OpenInviteDialog()
		{
			SteamNetworkLobby lobby = SteamManager.Instance.Lobby;
			if (lobby != null)
			{
				CSteamID lobbyId = lobby.LobbyId;
				if (lobbyId == CSteamID.Nil)
				{
					throw new NullReferenceException("currentLobbyId");
				}
				SteamFriends.ActivateGameOverlayInviteDialog(lobbyId);
			}
		}

		private static void SetState(SteamNetworkLobbyState steamNetworkLobbyState)
		{
			State = steamNetworkLobbyState;
		}

		internal static void Reset()
		{
			UnsubscribeFromCallbacksAndCallResults();
		}

		private static void UnsubscribeFromCallbacksAndCallResults()
		{
			SteamMatchmakingImpl.OnLobbyCreatedOK = (SteamMatchmakingImpl.LobbyCreatedOKCallResultDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyCreatedOK, new SteamMatchmakingImpl.LobbyCreatedOKCallResultDelegate(OnLobbyCreatedOK));
			SteamMatchmakingImpl.OnLobbyCreatedFail = (SteamMatchmakingImpl.LobbyCreatedFailCallResultDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyCreatedFail, new SteamMatchmakingImpl.LobbyCreatedFailCallResultDelegate(OnLobbyCreatedFail));
			SteamMatchmakingImpl.OnLobbyCreatedAccessDenied = (SteamMatchmakingImpl.LobbyCreatedAccessDeniedCallResultDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyCreatedAccessDenied, new SteamMatchmakingImpl.LobbyCreatedAccessDeniedCallResultDelegate(OnLobbyCreatedFail));
			SteamMatchmakingImpl.OnLobbyCreatedLimitExceeded = (SteamMatchmakingImpl.LobbyCreatedLimitExceededCallResultDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyCreatedLimitExceeded, new SteamMatchmakingImpl.LobbyCreatedLimitExceededCallResultDelegate(OnLobbyCreatedFail));
			SteamMatchmakingImpl.OnLobbyCreatedNoConnection = (SteamMatchmakingImpl.LobbyCreatedNoConnectionCallResultDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyCreatedNoConnection, new SteamMatchmakingImpl.LobbyCreatedNoConnectionCallResultDelegate(OnLobbyCreatedFail));
			SteamMatchmakingImpl.OnLobbyCreatedTimeout = (SteamMatchmakingImpl.LobbyCreatedTimeoutCallResultDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyCreatedTimeout, new SteamMatchmakingImpl.LobbyCreatedTimeoutCallResultDelegate(OnLobbyCreatedFail));
			SteamMatchmakingImpl.OnLobbyEnterInitiatedSuccess = (SteamMatchmakingImpl.LobbyEnterSuccessCallResultDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyEnterInitiatedSuccess, new SteamMatchmakingImpl.LobbyEnterSuccessCallResultDelegate(OnLobbyEnterInitiatedSuccess));
			SteamMatchmakingImpl.OnLobbyEnterInitiatedError = (SteamMatchmakingImpl.LobbyEnterErrorCallResultDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyEnterInitiatedError, new SteamMatchmakingImpl.LobbyEnterErrorCallResultDelegate(OnLobbyEnterInitiatedError));
			SteamMatchmakingImpl.OnLobbyEnterReceivedSuccess = (SteamMatchmakingImpl.LobbyEnterSuccessCallbackDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyEnterReceivedSuccess, new SteamMatchmakingImpl.LobbyEnterSuccessCallbackDelegate(OnLobbyEnterReceivedSuccess));
			SteamMatchmakingImpl.OnLobbyEnterReceivedError = (SteamMatchmakingImpl.LobbyEnterErrorCallbackDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyEnterReceivedError, new SteamMatchmakingImpl.LobbyEnterErrorCallbackDelegate(OnLobbyEnterReceivedError));
			SteamFriendsImpl.OnGameLobbyJoinRequested = (SteamFriendsImpl.GameLobbyJoinRequestedCallbackDelegate)Delegate.Remove(SteamFriendsImpl.OnGameLobbyJoinRequested, new SteamFriendsImpl.GameLobbyJoinRequestedCallbackDelegate(OnGameLobbyJoinRequested));
			SteamFriendsImpl.OnGameRichPresenceJoinRequested = (SteamFriendsImpl.GameRichPresenceJoinRequestedCallbackDelegate)Delegate.Remove(SteamFriendsImpl.OnGameRichPresenceJoinRequested, new SteamFriendsImpl.GameRichPresenceJoinRequestedCallbackDelegate(OnGameRichPresenceJoinRequested));
			SteamMatchmakingImpl.OnLobbyLeave = (SteamMatchmakingImpl.LobbyLeaveDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyLeave, new SteamMatchmakingImpl.LobbyLeaveDelegate(OnLobbyLeave));
			SteamMatchmakingImpl.OnLobbyMatchList = (SteamMatchmakingImpl.LobbyMatchListCallResultDelegate)Delegate.Remove(SteamMatchmakingImpl.OnLobbyMatchList, new SteamMatchmakingImpl.LobbyMatchListCallResultDelegate(OnLobbyMatchList));
		}
	}
	internal delegate void OnLobbyEnteredDelegate(SteamNetworkLobby steamNetworkLobby);
	internal delegate void OnLobbyLeftDelegate(SteamNetworkLobby steamNetworkLobby);
	internal sealed class SteamNetworkLobbyMember
	{
		internal CSteamID LobbyId { get; private set; }

		internal CSteamID UserId { get; private set; }

		internal bool IsReady { get; set; }

		internal ECharacter Character { get; set; }

		internal ESkinType SkinType { get; set; }

		internal bool HasSelectedCharacter { get; set; }

		internal SteamNetworkLobbyMember(CSteamID steamLobbyId, CSteamID steamUserId)
		{
			LobbyId = steamLobbyId;
			UserId = steamUserId;
		}
	}
	internal static class SteamNetworkManager
	{
		internal static SteamNetworkMode Mode { get; private set; }

		internal static void CreateAndStartServer()
		{
			SteamManager instance = SteamManager.Instance;
			if (!((Object)(object)instance == (Object)null))
			{
				if (instance.Server != null)
				{
					DestroyServer();
				}
				SteamNetworkServer steamNetworkServer = (instance.Server = new SteamNetworkServer());
				steamNetworkServer.StartListening();
				SetMode(SteamNetworkMode.Server);
			}
		}

		internal static void CreateServer()
		{
			SteamManager instance = SteamManager.Instance;
			if (!((Object)(object)instance == (Object)null))
			{
				if (instance.Server != null)
				{
					DestroyServer();
				}
				SteamNetworkServer server = new SteamNetworkServer();
				instance.Server = server;
				SetMode(SteamNetworkMode.Server);
			}
		}

		internal static void DestroyServer()
		{
			SteamManager instance = SteamManager.Instance;
			if (!((Object)(object)instance == (Object)null) && instance.Server != null)
			{
				SetMode(SteamNetworkMode.None);
				instance.Server.Dispose();
				instance.Server = null;
				MatchContext.EndMatch();
			}
		}

		internal static void CreateClientAndConnect(CSteamID steamUserId)
		{
			SteamManager instance = SteamManager.Instance;
			if (!((Object)(object)instance == (Object)null))
			{
				if (instance.Client != null)
				{
					DestroyClient();
				}
				SteamNetworkClient steamNetworkClient = (instance.Client = new SteamNetworkClient());
				steamNetworkClient.Connect(steamUserId);
				SetMode(SteamNetworkMode.Client);
			}
		}

		internal static void CreateClientAndConnect(CSteamID steamUserId, ClientConnectedDelegate clientConnectedDelegate)
		{
			SteamManager instance = SteamManager.Instance;
			if (!((Object)(object)instance == (Object)null))
			{
				if (instance.Client != null)
				{
					DestroyClient();
				}
				SteamNetworkClient steamNetworkClient = new SteamNetworkClient();
				steamNetworkClient.OnConnected = (ClientConnectedDelegate)Delegate.Combine(steamNetworkClient.OnConnected, clientConnectedDelegate);
				instance.Client = steamNetworkClient;
				steamNetworkClient.Connect(steamUserId);
				SetMode(SteamNetworkMode.Client);
			}
		}

		internal static void CreateClient()
		{
			SteamManager instance = SteamManager.Instance;
			if (!((Object)(object)instance == (Object)null))
			{
				if (instance.Client != null)
				{
					DestroyClient();
				}
				SteamNetworkClient client = new SteamNetworkClient();
				instance.Client = client;
				SetMode(SteamNetworkMode.Client);
			}
		}

		internal static void DestroyClient()
		{
			SteamManager instance = SteamManager.Instance;
			if (!((Object)(object)instance == (Object)null) && instance.Client != null)
			{
				SetMode(SteamNetworkMode.None);
				instance.Client.Dispose();
				instance.Client = null;
				MatchContext.EndMatch();
			}
		}

		internal static void StartMultiplayerGame(string sceneName)
		{
			if (string.IsNullOrWhiteSpace(sceneName))
			{
				throw new ArgumentNullException("sceneName");
			}
			_ = Mode;
			_ = 1;
		}

		private static void SetMode(SteamNetworkMode steamNetworkMode)
		{
			Mode = steamNetworkMode;
		}
	}
	internal sealed class SteamNetworkServer : IDisposable, IAsyncDisposable
	{
		internal const int VirtualPort = 0;

		private const int SteamNetworkMessageBufferSize = 512;

		private const int MaxNetworkReadsPerFrame = 4;

		private const int MaxNetworkWritesPerFrame = 4;

		private const double SendRate = 1.0 / 60.0;

		private const float KeepAliveInterval = 5f;

		internal static SteamNetworkServer Instance;

		private object _syncRoot = new object();

		private bool _disposedValue;

		private bool _netAuthenticationStatusCurrent;

		private bool _relayNetworkAccessStatusCurrent;

		private HSteamListenSocket _steamListenSocketHandle;

		private HSteamNetPollGroup _steamNetPollGroupHandle;

		private Dictionary<CSteamID, HSteamNetConnection> _connections;

		private Dictionary<HSteamNetConnection, HSteamNetPollGroup> _connectionPollGroup;

		private IntPtr[] _steamNetworkMessageReceiveBuffer;

		private IntPtr[] _steamNetworkMessageSendBuffer;

		private long[] _steamNetworkMessageSendResults;

		private ConcurrentQueue<SteamNetworkMessage> _steamNetworkMessageSendQueue;

		private NetworkMessageDispatcher _networkMessageDispatcher;

		private double _lastSendTime;

		private float _keepAliveTimer = 5f;

		internal ServerReadyToListenDelegate OnReadyToListen;

		internal bool IsListening { get; private set; }

		internal bool SafeRW { get; private set; }

		internal SteamNetworkServerState State { get; private set; }

		internal SteamNetworkServer(bool safeReadingAndWriting = true)
		{
			if (Instance != null)
			{
				throw new InvalidOperationException();
			}
			Instance = this;
			_connections = new Dictionary<CSteamID, HSteamNetConnection>(SteamNetworkLobbyManager.MaxPlayers);
			_connectionPollGroup = new Dictionary<HSteamNetConnection, HSteamNetPollGroup>(SteamNetworkLobbyManager.MaxPlayers);
			_steamNetworkMessageReceiveBuffer = new IntPtr[512];
			_steamNetworkMessageSendBuffer = new IntPtr[512];
			_steamNetworkMessageSendResults = new long[512];
			_steamNetworkMessageSendQueue = new ConcurrentQueue<SteamNetworkMessage>();
			_networkMessageDispatcher = new NetworkMessageDispatcher(isServer: true);
			SafeRW = safeReadingAndWriting;
			Setup();
			CheckSteamNetworkStatus();
		}

		private void Setup()
		{
			SubscribeToCallbacksAndCallResults();
		}

		private void SubscribeToCallbacksAndCallResults()
		{
			SteamNetworkingImpl.OnSteamNetAuthenticationStatusCurrent = (SteamNetworkingImpl.SteamNetAuthenticationStatusCurrentCallbackDelegate)Delegate.Combine(SteamNetworkingImpl.OnSteamNetAuthenticationStatusCurrent, new SteamNetworkingImpl.SteamNetAuthenticationStatusCurrentCallbackDelegate(OnSteamNetAuthenticationStatusCurrent));
			SteamNetworkingImpl.OnSteamRelayNetworkStatusCurrent = (SteamNetworkingImpl.SteamRelayNetworkStatusCurrentCallbackDelegate)Delegate.Combine(SteamNetworkingImpl.OnSteamRelayNetworkStatusCurrent, new SteamNetworkingImpl.SteamRelayNetworkStatusCurrentCallbackDelegate(OnSteamRelayNetworkStatusCurrent));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionRequest = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionRequestCallbackDelegate)Delegate.Combine(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionRequest, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionRequestCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionRequest));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionClosedOrRejected = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionClosedOrRejectedCallbackDelegate)Delegate.Combine(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionClosedOrRejected, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionClosedOrRejectedCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionClosedOrRejected));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionProblem = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionProblemCallbackDelegate)Delegate.Combine(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionProblem, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionProblemCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionProblem));
		}

		private void CheckSteamNetworkStatus()
		{
			if (SteamNetworkingUtils.GetRelayNetworkStatus(out var _) == ESteamNetworkingAvailability.k_ESteamNetworkingAvailability_Current)
			{
				OnSteamRelayNetworkStatusCurrent();
			}
			if (SteamNetworkingSockets.GetAuthenticationStatus(out var _) == ESteamNetworkingAvailability.k_ESteamNetworkingAvailability_Current)
			{
				OnSteamNetAuthenticationStatusCurrent();
			}
			if (!_relayNetworkAccessStatusCurrent || !_netAuthenticationStatusCurrent)
			{
				Task.Run((Func<ValueTask>)CheckSteamNetworkStatusAsync);
			}
		}

		private async ValueTask CheckSteamNetworkStatusAsync()
		{
			SteamRelayNetworkStatus_t pDetails;
			SteamNetAuthenticationStatus_t pDetails2;
			while (SteamNetworkingUtils.GetRelayNetworkStatus(out pDetails) != ESteamNetworkingAvailability.k_ESteamNetworkingAvailability_Current || SteamNetworkingSockets.GetAuthenticationStatus(out pDetails2) != ESteamNetworkingAvailability.k_ESteamNetworkingAvailability_Current)
			{
				await Task.Delay(TimeSpan.FromMilliseconds(100.0)).ConfigureAwait(continueOnCapturedContext: false);
			}
			SynchronizationContext.SetSynchronizationContext(BonkWithFriendsMod.Instance.MainThreadSyncContext);
			OnSteamRelayNetworkStatusCurrent();
			OnSteamNetAuthenticationStatusCurrent();
			OnReadyToListen?.Invoke();
		}

		private bool IsReadyToListen()
		{
			if (_netAuthenticationStatusCurrent)
			{
				return _relayNetworkAccessStatusCurrent;
			}
			return false;
		}

		internal void StartListening()
		{
			if (!IsReadyToListen())
			{
				ModLogger.Error("[StartListening] Not ready to listen!");
				return;
			}
			lock (_syncRoot)
			{
				SteamNetworkingConfigValue_t[] array = Array.Empty<SteamNetworkingConfigValue_t>();
				_steamListenSocketHandle = SteamNetworkingSockets.CreateListenSocketP2P(0, array.Length, array);
				if (_steamListenSocketHandle == HSteamListenSocket.Invalid)
				{
					ModLogger.Error("[StartListening] Steam listen socket handle invalid!");
					return;
				}
				_steamNetPollGroupHandle = SteamNetworkingSockets.CreatePollGroup();
				if (_steamNetPollGroupHandle == HSteamNetPollGroup.Invalid)
				{
					ModLogger.Error("[StartListening] Steam poll group handle invalid!");
					return;
				}
			}
			IsListening = true;
		}

		private void OnSteamNetAuthenticationStatusCurrent()
		{
			if (!_netAuthenticationStatusCurrent)
			{
				_netAuthenticationStatusCurrent = true;
			}
		}

		private void OnSteamRelayNetworkStatusCurrent()
		{
			if (!_relayNetworkAccessStatusCurrent)
			{
				_relayNetworkAccessStatusCurrent = true;
			}
		}

		private void OnSteamNetConnectionStatusChangedConnectionRequest(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState)
		{
			if (!IsListening || connection == HSteamNetConnection.Invalid)
			{
				SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
				return;
			}
			CSteamID nil = CSteamID.Nil;
			SteamNetworkingIdentity identityRemote = connectionInfo.m_identityRemote;
			if (identityRemote.m_eType == ESteamNetworkingIdentityType.k_ESteamNetworkingIdentityType_SteamID)
			{
				nil = identityRemote.GetSteamID();
				if (nil == CSteamID.Nil)
				{
					SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionRequest] Steam user id null!");
					return;
				}
				if (!SteamManager.Instance.Lobby.HasMember(nil))
				{
					SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionRequest] Attempted connection is not from a member in our lobby!");
					return;
				}
				EResult eResult = SteamNetworkingSockets.AcceptConnection(connection);
				if (eResult == EResult.k_EResultInvalidParam || eResult == EResult.k_EResultInvalidState)
				{
					SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionRequest] Steam connection handle invalid!");
					return;
				}
				lock (_syncRoot)
				{
					_connections[nil] = connection;
					if (!SteamNetworkingSockets.SetConnectionPollGroup(connection, _steamNetPollGroupHandle))
					{
						ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionRequest] Steam connection or poll group handle invalid!");
					}
					else
					{
						_connectionPollGroup[connection] = _steamNetPollGroupHandle;
					}
					return;
				}
			}
			SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
			throw new ArgumentException("steamNetworkingIdentity");
		}

		private void OnSteamNetConnectionStatusChangedConnectionClosedOrRejected(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState)
		{
			if (!IsListening || connection == HSteamNetConnection.Invalid)
			{
				SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
				return;
			}
			CSteamID nil = CSteamID.Nil;
			SteamNetworkingIdentity identityRemote = connectionInfo.m_identityRemote;
			if (identityRemote.m_eType == ESteamNetworkingIdentityType.k_ESteamNetworkingIdentityType_SteamID)
			{
				nil = identityRemote.GetSteamID();
				if (nil == CSteamID.Nil)
				{
					SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionClosedOrRejected] Steam user id null!");
					return;
				}
				lock (_syncRoot)
				{
					if (_connectionPollGroup.TryGetValue(connection, out var _) && SteamNetworkingSockets.SetConnectionPollGroup(connection, HSteamNetPollGroup.Invalid) && !_connectionPollGroup.Remove(connection))
					{
						ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionClosedOrRejected] Unable to unassign connection from poll group!");
					}
					if (_connections.ContainsValue(connection))
					{
						KeyValuePair<CSteamID, HSteamNetConnection> keyValuePair = _connections.FirstOrDefault((KeyValuePair<CSteamID, HSteamNetConnection> c) => c.Value == connection);
						if (keyValuePair.Key == CSteamID.Nil || keyValuePair.Value == HSteamNetConnection.Invalid)
						{
							throw new NullReferenceException("entry");
						}
						if (!_connections.Remove(keyValuePair.Key))
						{
							ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionClosedOrRejected] Unable to remove connection!");
						}
						SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					}
					return;
				}
			}
			SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
			throw new ArgumentException("steamNetworkingIdentity");
		}

		private void OnSteamNetConnectionStatusChangedConnectionProblem(HSteamNetConnection connection, SteamNetConnectionInfo_t connectionInfo, ESteamNetworkingConnectionState oldState)
		{
			if (!IsListening || connection == HSteamNetConnection.Invalid)
			{
				SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
				return;
			}
			CSteamID nil = CSteamID.Nil;
			SteamNetworkingIdentity identityRemote = connectionInfo.m_identityRemote;
			if (identityRemote.m_eType == ESteamNetworkingIdentityType.k_ESteamNetworkingIdentityType_SteamID)
			{
				nil = identityRemote.GetSteamID();
				if (nil == CSteamID.Nil)
				{
					SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionProblem] Steam user id null!");
					return;
				}
				lock (_syncRoot)
				{
					if (_connectionPollGroup.TryGetValue(connection, out var _) && SteamNetworkingSockets.SetConnectionPollGroup(connection, HSteamNetPollGroup.Invalid) && !_connectionPollGroup.Remove(connection))
					{
						ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionProblem] Unable to unassign connection from poll group!");
					}
					if (_connections.ContainsValue(connection))
					{
						KeyValuePair<CSteamID, HSteamNetConnection> keyValuePair = _connections.FirstOrDefault((KeyValuePair<CSteamID, HSteamNetConnection> c) => c.Value == connection);
						if (keyValuePair.Key == CSteamID.Nil || keyValuePair.Value == HSteamNetConnection.Invalid)
						{
							throw new NullReferenceException("entry");
						}
						if (!_connections.Remove(keyValuePair.Key))
						{
							ModLogger.Error("[OnSteamNetConnectionStatusChangedConnectionProblem] Unable to remove connection!");
						}
						SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
					}
					return;
				}
			}
			SteamNetworkingSockets.CloseConnection(connection, 0, string.Empty, bEnableLinger: true);
			throw new ArgumentException("steamNetworkingIdentity");
		}

		internal void FixedUpdate(float fixedDeltaTime, double fixedTimeAsDouble)
		{
		}

		internal void Update(float deltaTime, double timeAsDouble)
		{
			if (_steamListenSocketHandle == HSteamListenSocket.Invalid || _steamNetPollGroupHandle == HSteamNetPollGroup.Invalid || !IsListening)
			{
				return;
			}
			int num = 0;
			int num2 = 0;
			do
			{
				num2 = SteamNetworkingSockets.ReceiveMessagesOnPollGroup(_steamNetPollGroupHandle, _steamNetworkMessageReceiveBuffer, _steamNetworkMessageReceiveBuffer.Length);
				if (num2 <= 0)
				{
					break;
				}
				if (SafeRW)
				{
					SafeUpdate(num2);
				}
				else
				{
					UnsafeUpdate(num2);
				}
				num++;
				if (num >= 4)
				{
					num = 0;
					break;
				}
			}
			while (num2 == _steamNetworkMessageReceiveBuffer.Length);
			if (timeAsDouble - _lastSendTime > 1.0 / 60.0)
			{
				int num3 = 0;
				SteamNetworkMessage result;
				while (_steamNetworkMessageSendQueue.TryDequeue(out result))
				{
					if (result == null)
					{
						continue;
					}
					try
					{
						if (SafeRW)
						{
							SafeSend(result, num3);
						}
						else
						{
							UnsafeSend(result, num3);
						}
					}
					catch (Exception ex)
					{
						ModLogger.Error($"[Update] Failed to send message - Size: {result.GetLength()}, Flags: {result.SendFlags}, Error: {ex.Message}");
					}
					finally
					{
						NetworkMessagePool.Return(result);
					}
					num3++;
					if (num3 >= _steamNetworkMessageSendBuffer.Length)
					{
						break;
					}
				}
				_lastSendTime = timeAsDouble;
			}
			_keepAliveTimer -= deltaTime;
			if (_keepAliveTimer <= 0f)
			{
				BroadcastMessage(new KeepAliveMessage());
				_keepAliveTimer = 5f;
			}
		}

		private void SafeSend(SteamNetworkMessage steamNetworkMessage, int sentMessages)
		{
			byte[] buffer = steamNetworkMessage.GetBuffer();
			long length = steamNetworkMessage.GetLength();
			if (length >= int.MaxValue)
			{
				throw new InvalidOperationException();
			}
			HSteamNetConnection steamNetConnectionHandle = steamNetworkMessage.SteamNetConnectionHandle;
			int sendFlags = (int)steamNetworkMessage.SendFlags;
			GCHandle gCHandle = GCHandle.Alloc(buffer, GCHandleType.Pinned);
			try
			{
				SteamNetworkingSockets.SendMessageToConnection(steamNetConnectionHandle, gCHandle.AddrOfPinnedObject(), (uint)length, sendFlags, out var _);
			}
			finally
			{
				gCHandle.Free();
			}
			NetProfiler.TrackMessageSent((byte)steamNetworkMessage.Type, (int)length);
		}

		private void UnsafeSend(SteamNetworkMessage steamNetworkMessage, int sentMessages)
		{
		}

		internal void SendMessage<TMsg>(TMsg tMsg, CSteamID steamUserId, HSteamNetConnection steamNetConnectionHandle = default(HSteamNetConnection)) where TMsg : MessageBase
		{
			if (!IsListening || _steamListenSocketHandle == HSteamListenSocket.Invalid || _steamNetPollGroupHandle == HSteamNetPollGroup.Invalid || steamUserId == CSteamID.Nil)
			{
				return;
			}
			if (steamNetConnectionHandle == HSteamNetConnection.Invalid)
			{
				lock (_syncRoot)
				{
					if (!_connections.TryGetValue(steamUserId, out steamNetConnectionHandle))
					{
						return;
					}
				}
			}
			var (type, flags) = _networkMessageDispatcher.GetMessageTypeAndSendFlags(tMsg.GetType());
			try
			{
				SteamNetworkMessage steamNetworkMessage = NetworkMessagePool.RentSend(steamUserId, steamNetConnectionHandle, type, flags);
				steamNetworkMessage.Serialize(tMsg);
				_steamNetworkMessageSendQueue.Enqueue(steamNetworkMessage);
			}
			catch (Exception ex)
			{
				ModLogger.Error("[SendMessage] Failed to send " + typeof(TMsg).Name + ": " + ex.Message);
			}
		}

		internal void BroadcastMessage<TMsg>(TMsg tMsg) where TMsg : MessageBase
		{
			if (!IsListening || _steamListenSocketHandle == HSteamListenSocket.Invalid || _steamNetPollGroupHandle == HSteamNetPollGroup.Invalid)
			{
				return;
			}
			var (type, flags) = _networkMessageDispatcher.GetMessageTypeAndSendFlags(tMsg.GetType());
			lock (_syncRoot)
			{
				foreach (KeyValuePair<CSteamID, HSteamNetConnection> connection in _connections)
				{
					try
					{
						CSteamID key = connection.Key;
						HSteamNetConnection value = connection.Value;
						SteamNetworkMessage steamNetworkMessage = NetworkMessagePool.RentSend(key, value, type, flags);
						steamNetworkMessage.Serialize(tMsg);
						_steamNetworkMessageSendQueue.Enqueue(steamNetworkMessage);
					}
					catch
					{
					}
				}
			}
		}

		internal void BroadcastMessageExcept<TMsg>(TMsg tMsg, CSteamID excludedSteamUserId, HSteamNetConnection excludedSteamNetConnectionHandle = default(HSteamNetConnection)) where TMsg : MessageBase
		{
			if (!IsListening || _steamListenSocketHandle == HSteamListenSocket.Invalid || _steamNetPollGroupHandle == HSteamNetPollGroup.Invalid || excludedSteamUserId == CSteamID.Nil)
			{
				return;
			}
			if (excludedSteamNetConnectionHandle == HSteamNetConnection.Invalid)
			{
				lock (_syncRoot)
				{
					if (!_connections.TryGetValue(excludedSteamUserId, out excludedSteamNetConnectionHandle))
					{
						return;
					}
				}
			}
			var (type, flags) = _networkMessageDispatcher.GetMessageTypeAndSendFlags(tMsg.GetType());
			lock (_syncRoot)
			{
				foreach (KeyValuePair<CSteamID, HSteamNetConnection> connection in _connections)
				{
					try
					{
						CSteamID key = connection.Key;
						HSteamNetConnection value = connection.Value;
						if (!(key == excludedSteamUserId) && !(value == excludedSteamNetConnectionHandle))
						{
							SteamNetworkMessage steamNetworkMessage = NetworkMessagePool.RentSend(key, value, type, flags);
							steamNetworkMessage.Serialize(tMsg);
							_steamNetworkMessageSendQueue.Enqueue(steamNetworkMessage);
						}
					}
					catch
					{
					}
				}
			}
		}

		internal void LateUpdate(float deltaTime, double timeAsDouble)
		{
		}

		private void SafeUpdate(int receivedMessages)
		{
			for (int i = 0; i < receivedMessages; i++)
			{
				IntPtr intPtr = _steamNetworkMessageReceiveBuffer[i];
				if (intPtr == IntPtr.Zero)
				{
					continue;
				}
				SteamNetworkingMessage_t message = SteamNetworkingMessage_t.FromIntPtr(intPtr);
				SteamNetworkMessage steamNetworkMessage = null;
				try
				{
					steamNetworkMessage = NetworkMessagePool.RentReceive(message, SafeRW);
					NetProfiler.TrackMessageReceived((byte)steamNetworkMessage.Type, message.m_cbSize);
					_networkMessageDispatcher.Dispatch(steamNetworkMessage);
				}
				finally
				{
					if (steamNetworkMessage != null)
					{
						NetworkMessagePool.Return(steamNetworkMessage);
					}
					SteamNetworkingMessage_t.Release(intPtr);
					_steamNetworkMessageReceiveBuffer[i] = IntPtr.Zero;
				}
			}
		}

		private unsafe void UnsafeUpdate(int receivedMessages)
		{
			for (int i = 0; i < receivedMessages; i++)
			{
				IntPtr intPtr = _steamNetworkMessageReceiveBuffer[i];
				if (intPtr == IntPtr.Zero)
				{
					continue;
				}
				SteamNetworkingMessage_t message = Unsafe.ReadUnaligned<SteamNetworkingMessage_t>(intPtr.ToPointer());
				SteamNetworkMessage steamNetworkMessage = null;
				try
				{
					steamNetworkMessage = NetworkMessagePool.RentReceive(message, SafeRW);
					_networkMessageDispatcher.Dispatch(steamNetworkMessage);
				}
				finally
				{
					if (steamNetworkMessage != null)
					{
						NetworkMessagePool.Return(steamNetworkMessage);
					}
					SteamNetworkingMessage_t.Release(intPtr);
					_steamNetworkMessageReceiveBuffer[i] = IntPtr.Zero;
				}
			}
		}

		[NetworkMessageHandler(MessageType.KeepAlive)]
		private void HandleKeepAlive(SteamNetworkMessage steamNetworkMessage)
		{
		}

		[NetworkMessageHandler(MessageType.ClientIntroduce)]
		private void HandleClientIntroduce(SteamNetworkMessage steamNetworkMessage)
		{
			//IL_0095: Unknown result type (might be due to invalid IL or missing references)
			//IL_009f: Expected I4, but got Unknown
			ClientIntroduceMessage clientIntroduceMessage = steamNetworkMessage.Deserialize<ClientIntroduceMessage>();
			CSteamID steamUserId = steamNetworkMessage.SteamUserId;
			PlayerJoinedMessage tMsg = new PlayerJoinedMessage
			{
				Character = clientIntroduceMessage.Character
			};
			BroadcastMessageExcept(tMsg, steamUserId);
			HostWelcomeMessage hostWelcomeMessage = new HostWelcomeMessage();
			SteamNetworkLobby lobby = SteamManager.Instance.Lobby;
			if (lobby != null)
			{
				foreach (SteamNetworkLobbyMember member in lobby.Members)
				{
					if (!(member.UserId == steamUserId))
					{
						hostWelcomeMessage.ExistingPlayers.Add(new HostWelcomeMessage.PlayerInfo
						{
							SteamUserId = member.UserId.m_SteamID,
							Character = (int)member.Character
						});
					}
				}
			}
			SendMessage(hostWelcomeMessage, steamUserId);
		}

		[NetworkMessageHandler(MessageType.PrefabReady)]
		private void HandleClientPrefabsReady(SteamNetworkMessage steamNetworkMessage)
		{
			_ = steamNetworkMessage.SteamUserId;
			MatchContext.Current?.SpawnedObjects.BroadcastPendingSpawns();
		}

		[NetworkMessageHandler(MessageType.Chat)]
		private void HandleChatMessage(SteamNetworkMessage steamNetworkMessage)
		{
			ChatMessage chatMessage = steamNetworkMessage.Deserialize<ChatMessage>();
			CSteamID steamUserId = steamNetworkMessage.SteamUserId;
			chatMessage.SenderSteamId = steamUserId.m_SteamID;
			BroadcastMessageExcept(chatMessage, steamUserId);
			ChatWindowUi.Instance?.AddMessage(steamUserId.m_SteamID, chatMessage.Text);
		}

		internal void DisconnectClient(CSteamID steamUserId, string reason = "Disconnected by server")
		{
			lock (_syncRoot)
			{
				if (_connections.TryGetValue(steamUserId, out var value) && !(value == HSteamNetConnection.Invalid))
				{
					if (_connectionPollGroup.TryGetValue(value, out var _))
					{
						SteamNetworkingSockets.SetConnectionPollGroup(value, HSteamNetPollGroup.Invalid);
						_connectionPollGroup.Remove(value);
					}
					_connections.Remove(steamUserId);
					SteamNetworkingSockets.CloseConnection(value, 0, reason, bEnableLinger: true);
				}
			}
		}

		private void SetState(SteamNetworkServerState steamNetworkServerState)
		{
			State = steamNetworkServerState;
		}

		internal void Reset()
		{
			CloseAllConnectionsAndDestroy();
			UnsubscribeFromCallbacksAndCallResults();
			ResetNetworkMessageDispatcher();
			Array.Clear(_steamNetworkMessageReceiveBuffer);
			Array.Clear(_steamNetworkMessageSendBuffer);
			Array.Clear(_steamNetworkMessageSendResults);
			_steamNetworkMessageSendQueue.Clear();
			Instance = null;
		}

		private void CloseAllConnectionsAndDestroy()
		{
			if (_steamListenSocketHandle == HSteamListenSocket.Invalid)
			{
				return;
			}
			if (_steamNetPollGroupHandle != HSteamNetPollGroup.Invalid)
			{
				Dictionary<HSteamNetConnection, HSteamNetPollGroup> connectionPollGroup = _connectionPollGroup;
				if (connectionPollGroup != null && connectionPollGroup.Count > 0)
				{
					foreach (KeyValuePair<HSteamNetConnection, HSteamNetPollGroup> item in _connectionPollGroup)
					{
						if (!(item.Key == HSteamNetConnection.Invalid))
						{
							SteamNetworkingSockets.SetConnectionPollGroup(item.Key, HSteamNetPollGroup.Invalid);
						}
					}
					_connectionPollGroup.Clear();
				}
				SteamNetworkingSockets.DestroyPollGroup(_steamNetPollGroupHandle);
			}
			Dictionary<CSteamID, HSteamNetConnection> connections = _connections;
			if (connections != null && connections.Count > 0)
			{
				foreach (KeyValuePair<CSteamID, HSteamNetConnection> connection in _connections)
				{
					if (!(connection.Value == HSteamNetConnection.Invalid))
					{
						SteamNetworkingSockets.CloseConnection(connection.Value, 0, string.Empty, bEnableLinger: true);
					}
				}
				_connections.Clear();
			}
			SteamNetworkingSockets.CloseListenSocket(_steamListenSocketHandle);
		}

		private void UnsubscribeFromCallbacksAndCallResults()
		{
			SteamNetworkingImpl.OnSteamNetAuthenticationStatusCurrent = (SteamNetworkingImpl.SteamNetAuthenticationStatusCurrentCallbackDelegate)Delegate.Remove(SteamNetworkingImpl.OnSteamNetAuthenticationStatusCurrent, new SteamNetworkingImpl.SteamNetAuthenticationStatusCurrentCallbackDelegate(OnSteamNetAuthenticationStatusCurrent));
			SteamNetworkingImpl.OnSteamRelayNetworkStatusCurrent = (SteamNetworkingImpl.SteamRelayNetworkStatusCurrentCallbackDelegate)Delegate.Remove(SteamNetworkingImpl.OnSteamRelayNetworkStatusCurrent, new SteamNetworkingImpl.SteamRelayNetworkStatusCurrentCallbackDelegate(OnSteamRelayNetworkStatusCurrent));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionRequest = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionRequestCallbackDelegate)Delegate.Remove(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionRequest, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionRequestCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionRequest));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionClosedOrRejected = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionClosedOrRejectedCallbackDelegate)Delegate.Remove(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionClosedOrRejected, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionClosedOrRejectedCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionClosedOrRejected));
			SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionProblem = (SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionProblemCallbackDelegate)Delegate.Remove(SteamNetworkingImpl.OnSteamNetConnectionStatusChangedConnectionProblem, new SteamNetworkingImpl.SteamNetConnectionStatusChangedConnectionProblemCallbackDelegate(OnSteamNetConnectionStatusChangedConnectionProblem));
		}

		private void ResetNetworkMessageDispatcher()
		{
			_networkMessageDispatcher?.Reset();
		}

		private void Dispose(bool disposing)
		{
			if (!_disposedValue)
			{
				if (disposing)
				{
					Reset();
				}
				_disposedValue = true;
			}
		}

		public void Dispose()
		{
			Dispose(disposing: true);
			GC.SuppressFinalize(this);
		}

		public async ValueTask DisposeAsync()
		{
			Dispose();
		}
	}
	internal delegate void ServerReadyToListenDelegate();
}
namespace Megabonk.BonkWithFriends.Networking.Models
{
	internal enum OrbType : byte
	{
		Bleed,
		Following,
		Shooty
	}
	public struct BossOrbModel
	{
		public uint Id { get; set; }

		public Vector3 Position { get; set; }
	}
}
namespace Megabonk.BonkWithFriends.Networking.Messages
{
	internal abstract class MessageBase : INetworkSerializable, IAsyncNetworkSerializable
	{
		public virtual void Deserialize(NetworkReader networkReader)
		{
		}

		public virtual void Serialize(NetworkWriter networkWriter)
		{
		}

		public virtual async ValueTask DeserializeAsync(NetworkReader networkReader)
		{
		}

		public virtual async ValueTask SerializeAsync(NetworkWriter networkWriter)
		{
		}

		internal static (MessageType type, MessageSendFlags sendFlags) GetMessageTypeAndSendFlags(Type t)
		{
			if (t == null)
			{
				throw new ArgumentNullException("t");
			}
			if (!t.IsSubclassOf(typeof(MessageBase)))
			{
				throw new ArgumentException("t");
			}
			NetworkMessageAttribute customAttribute = t.GetCustomAttribute<NetworkMessageAttribute>();
			if (customAttribute == null)
			{
				throw new NullReferenceException("networkMessageAttribute");
			}
			return (type: customAttribute.Type, sendFlags: customAttribute.SendFlags);
		}
	}
	[Flags]
	internal enum MessageSendFlags
	{
		Unreliable = 0,
		NoNagle = 1,
		UnreliableNoNagle = 1,
		NoDelay = 4,
		UnreliableNoDelay = 5,
		Reliable = 8,
		ReliableNoNagle = 9
	}
	internal enum MessageType : ushort
	{
		None = 0,
		ServerBase = 1,
		ServerHello = 2,
		HostWelcome = 3,
		TimeSyncResponse = 4,
		PlayerJoined = 5,
		PlayerLeft = 6,
		SeedSync = 7,
		LoadStage = 8,
		GameStarted = 9,
		GameOver = 10,
		EnemySpawned = 11,
		EnemyStatBatch = 12,
		EnemyStateBatch = 13,
		TimelineEvent = 14,
		WaveCue = 15,
		WaveFinalCue = 16,
		BossSpawnSync = 17,
		BossDied = 18,
		WavesStopped = 19,
		SpawnedObjectBatch = 20,
		PlayerRevived = 21,
		ReviveShrineSpawn = 22,
		EnemySpecialAttack = 23,
		ServerReadyForSpawnSync = 24,
		AllPlayersReadyForSpawn = 25,
		PickupSpawned = 26,
		PickupDespawned = 27,
		ClientBase = 16384,
		ClientHello = 16385,
		ClientIntroduce = 16386,
		TimeSyncRequest = 16387,
		Ready = 16388,
		PlayerDamaged = 16389,
		PlayerHealed = 16390,
		PlayerDied = 16391,
		PlayerReviveRequest = 16392,
		LevelUp = 16393,
		PrefabReady = 16394,
		PlayerReadyForSpawn = 16395,
		SharedBase = 32768,
		Acknowledge = 32769,
		ReliableBatch = 32770,
		UnreliableBatch = 32771,
		KeepAlive = 32772,
		PlayerDamagedRelay = 32773,
		PlayerHealedRelay = 32774,
		PlayerDiedRelay = 32775,
		PickupCollected = 32776,
		WeaponAdded = 32777,
		WeaponProjectileSpawned = 32778,
		WeaponProjectileHit = 32779,
		ProjectileSpawned = 32780,
		EnemyDamaged = 32781,
		EnemyDied = 32782,
		PlayerState = 32783,
		XpGained = 32784,
		InteractableUsed = 32785,
		StartChargingShrine = 32786,
		StopChargingShrine = 32787,
		Chat = 32788,
		AnimationState = 32789,
		PlayerMovement = 32790,
		WeaponAttackStarted = 32791,
		FinalBossOrbSpawned = 32792,
		FinalBossOrbsUpdate = 32793,
		FinalBossOrbDestroyed = 32794,
		BossLampCharge = 32795,
		BossPylonCharge = 32796
	}
	[AttributeUsage(AttributeTargets.Class | AttributeTargets.Struct)]
	internal sealed class NetworkMessageAttribute : Attribute
	{
		internal readonly MessageType Type;

		internal readonly MessageSendFlags SendFlags;

		internal NetworkMessageAttribute(MessageType messageType, MessageSendFlags sendFlags)
		{
			if (messageType == MessageType.None)
			{
				throw new ArgumentOutOfRangeException("messageType");
			}
			Type = messageType;
			SendFlags = sendFlags;
		}
	}
	internal sealed class NetworkMessageDispatcher
	{
		private const int DefaultNetworkMessageCacheSize = 32;

		private const int DefaultHandlerSize = 16;

		private Dictionary<Type, NetworkMessageAttribute> _networkMessageCache;

		private Dictionary<MessageType, MessageSendFlags> _sendFlagsCache;

		private Dictionary<MessageType, SteamNetworkMessageDelegate> _handlers;

		private bool _isServer;

		internal bool IsSetup { get; private set; }

		internal NetworkMessageDispatcher(bool isServer)
		{
			_isServer = isServer;
			_networkMessageCache = new Dictionary<Type, NetworkMessageAttribute>(32);
			_sendFlagsCache = new Dictionary<MessageType, MessageSendFlags>(32);
			_handlers = new Dictionary<MessageType, SteamNetworkMessageDelegate>(16);
			Setup();
		}

		private void Setup()
		{
			Type[] types = Assembly.GetExecutingAssembly().GetTypes();
			Type[] array = types;
			foreach (Type type in array)
			{
				if (!(type == null) && type.IsSubclassOf(typeof(MessageBase)))
				{
					NetworkMessageAttribute customAttribute = type.GetCustomAttribute<NetworkMessageAttribute>();
					if (customAttribute != null)
					{
						_networkMessageCache[type] = customAttribute;
						_sendFlagsCache[customAttribute.Type] = customAttribute.SendFlags;
					}
				}
			}
			array = types;
			foreach (Type type2 in array)
			{
				if (type2 == null)
				{
					continue;
				}
				MethodInfo[] methods = type2.GetMethods(BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic);
				MethodInfo[] methods2 = type2.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
				MemberInfo memberInfo = null;
				FieldInfo field = type2.GetField("Instance", BindingFlags.IgnoreCase | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic);
				PropertyInfo property = type2.GetProperty("Instance", BindingFlags.IgnoreCase | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic);
				if (field != null)
				{
					memberInfo = field;
				}
				else if (property != null)
				{
					memberInfo = property;
				}
				MethodInfo[] array2 = methods;
				foreach (MethodInfo methodInfo in array2)
				{
					if (methodInfo == null)
					{
						continue;
					}
					NetworkMessageHandlerAttribute customAttribute2 = methodInfo.GetCustomAttribute<NetworkMessageHandlerAttribute>();
					if (customAttribute2 == null || customAttribute2.Type == MessageType.None)
					{
						continue;
					}
					ParameterInfo returnParameter = methodInfo.ReturnParameter;
					if (returnParameter == null || returnParameter.ParameterType != typeof(void))
					{
						continue;
					}
					ParameterInfo[] parameters = methodInfo.GetParameters();
					if (parameters == null || parameters.Length != 1)
					{
						continue;
					}
					ParameterInfo parameterInfo = parameters[0];
					if (parameterInfo != null && !(parameterInfo.ParameterType != typeof(SteamNetworkMessage)))
					{
						MessageType type3 = customAttribute2.Type;
						ParameterExpression parameterExpression = Expression.Parameter(typeof(SteamNetworkMessage), "SteamNetworkMessage".ToLower());
						SteamNetworkMessageDelegate value = Expression.Lambda<Action<SteamNetworkMessage>>(Expression.Call(methodInfo, parameterExpression), new ParameterExpression[1] { parameterExpression }).Compile().Invoke;
						if (type3 != MessageType.None)
						{
							_handlers[type3] = value;
						}
					}
				}
				array2 = methods2;
				foreach (MethodInfo methodInfo2 in array2)
				{
					if (methodInfo2 == null)
					{
						continue;
					}
					NetworkMessageHandlerAttribute customAttribute3 = methodInfo2.GetCustomAttribute<NetworkMessageHandlerAttribute>();
					if (customAttribute3 == null || customAttribute3.Type == MessageType.None)
					{
						continue;
					}
					if (memberInfo == null)
					{
						throw new NullReferenceException("fieldOrPropertyInfo for: " + type2.FullName);
					}
					ParameterInfo returnParameter2 = methodInfo2.ReturnParameter;
					if (returnParameter2 == null || returnParameter2.ParameterType != typeof(void))
					{
						continue;
					}
					ParameterInfo[] parameters2 = methodInfo2.GetParameters();
					if (parameters2 == null || parameters2.Length != 1)
					{
						continue;
					}
					ParameterInfo parameterInfo2 = parameters2[0];
					if (parameterInfo2 == null || parameterInfo2.ParameterType != typeof(SteamNetworkMessage))
					{
						continue;
					}
					MessageType type4 = customAttribute3.Type;
					ParameterExpression parameterExpression2 = Expression.Parameter(typeof(SteamNetworkMessage), "SteamNetworkMessage".ToLower());
					Type baseType = memberInfo.GetType().BaseType;
					Type? baseType2 = baseType.BaseType;
					MemberExpression memberExpression = null;
					if (baseType2 == typeof(FieldInfo))
					{
						FieldInfo field2 = memberInfo as FieldInfo;
						memberExpression = Expression.Field(null, field2);
					}
					else if (baseType == typeof(PropertyInfo))
					{
						PropertyInfo property2 = memberInfo as PropertyInfo;
						memberExpression = Expression.Property(null, property2);
					}
					if (memberExpression == null)
					{
						continue;
					}
					Type type5 = memberExpression.Type;
					MethodCallExpression ifTrue = Expression.Call(memberExpression, methodInfo2, parameterExpression2);
					SteamNetworkMessageDelegate steamNetworkMessageDelegate = Expression.Lambda<Action<SteamNetworkMessage>>(Expression.IfThen(Expression.NotEqual(memberExpression, Expression.Constant(null, type5)), ifTrue), new ParameterExpression[1] { parameterExpression2 }).Compile().Invoke;
					if (type4 != MessageType.None)
					{
						if (_handlers.TryGetValue(type4, out var value2))
						{
							_handlers[type4] = (SteamNetworkMessageDelegate)Delegate.Combine(value2, steamNetworkMessageDelegate);
						}
						else
						{
							_handlers[type4] = steamNetworkMessageDelegate;
						}
					}
				}
			}
			IsSetup = true;
		}

		internal SteamNetworkMessageDelegate GetHandler(MessageType messageType)
		{
			Dictionary<MessageType, SteamNetworkMessageDelegate> handlers = _handlers;
			if (handlers != null && handlers.Count > 0 && messageType != MessageType.None && _handlers.TryGetValue(messageType, out var value))
			{
				return value;
			}
			return null;
		}

		internal SteamNetworkMessageDelegate GetHandler(Type type)
		{
			if (!_networkMessageCache.TryGetValue(type, out var value))
			{
				return null;
			}
			MessageType type2 = value.Type;
			if (type2 == MessageType.None)
			{
				return null;
			}
			Dictionary<MessageType, SteamNetworkMessageDelegate> handlers = _handlers;
			if (handlers != null && handlers.Count > 0 && type2 != MessageType.None && _handlers.TryGetValue(type2, out var value2))
			{
				return value2;
			}
			return null;
		}

		internal (MessageType messageType, MessageSendFlags messageSendFlags) GetMessageTypeAndSendFlags(Type type)
		{
			if (!_networkMessageCache.TryGetValue(type, out var value))
			{
				return default((MessageType, MessageSendFlags));
			}
			if (value.Type == MessageType.None)
			{
				return default((MessageType, MessageSendFlags));
			}
			return (messageType: value.Type, messageSendFlags: value.SendFlags);
		}

		internal MessageSendFlags GetMessageSendFlags(MessageType messageType)
		{
			if (messageType == MessageType.None)
			{
				throw new ArgumentOutOfRangeException("messageType");
			}
			if (!_sendFlagsCache.TryGetValue(messageType, out var value))
			{
				throw new KeyNotFoundException("messageType");
			}
			return value;
		}

		internal void Dispatch(SteamNetworkMessage steamNetworkMessage)
		{
			if (!IsSetup || steamNetworkMessage == null)
			{
				return;
			}
			MessageType type = steamNetworkMessage.Type;
			if ((_isServer && (int)type > 1 && (int)type < 16384) || (!_isServer && (int)type > 16384 && (int)type < 32768))
			{
				return;
			}
			SteamNetworkMessageDelegate handler = GetHandler(type);
			if (handler == null)
			{
				return;
			}
			try
			{
				handler(steamNetworkMessage);
			}
			catch (Exception ex)
			{
				ModLogger.Error(ex);
			}
		}

		internal void Reset()
		{
			_networkMessageCache?.Clear();
			_sendFlagsCache?.Clear();
			_handlers?.Clear();
		}
	}
	internal delegate void SteamNetworkMessageDelegate(SteamNetworkMessage steamNetworkMessage);
	internal delegate void SteamNetworkMessageInstanceDelegate<T>(T instance, SteamNetworkMessage steamNetworkMessage);
	[AttributeUsage(AttributeTargets.Method | AttributeTargets.Delegate)]
	internal sealed class NetworkMessageHandlerAttribute : Attribute
	{
		internal readonly MessageType Type;

		internal NetworkMessageHandlerAttribute(MessageType messageType)
		{
			if (messageType == MessageType.None)
			{
				throw new ArgumentOutOfRangeException("messageType");
			}
			Type = messageType;
		}
	}
	internal static class NetworkMessagePool
	{
		private static readonly Stack<SteamNetworkMessage> _pool = new Stack<SteamNetworkMessage>();

		public static SteamNetworkMessage RentSend(CSteamID target, HSteamNetConnection conn, MessageType type, MessageSendFlags flags)
		{
			if (!_pool.TryPop(out var result))
			{
				result = new SteamNetworkMessage();
			}
			result.InitSend(target, conn, type, flags);
			return result;
		}

		public static SteamNetworkMessage RentReceive(SteamNetworkingMessage_t message, bool safeRW)
		{
			if (!_pool.TryPop(out var result))
			{
				result = new SteamNetworkMessage();
			}
			result.InitReceive(message, safeRW);
			return result;
		}

		public static void Return(SteamNetworkMessage msg)
		{
			if (msg != null)
			{
				msg.Reset();
				_pool.Push(msg);
			}
		}
	}
	internal sealed class SteamNetworkMessage : IDisposable
	{
		private const int DefaultMemoryStreamSize = 1200;

		private bool _disposedValue;

		private MemoryStream _stream;

		private UnmanagedMemoryStream _unmanagedStream;

		private NetworkWriter _writer;

		private NetworkReader _reader;

		private bool _safeRW;

		internal MessageType Type;

		internal MessageSendFlags SendFlags;

		internal CSteamID SteamUserId;

		internal HSteamNetConnection SteamNetConnectionHandle;

		internal SteamNetworkMessage()
		{
			_stream = new MemoryStream(1200);
			_writer = new NetworkWriter(_stream);
			_reader = new NetworkReader(_stream);
			_safeRW = true;
		}

		internal void InitSend(CSteamID steamUserId, HSteamNetConnection steamNetConnectionHandle, MessageType messageType, MessageSendFlags messageSendFlags)
		{
			SteamUserId = steamUserId;
			SteamNetConnectionHandle = steamNetConnectionHandle;
			Type = messageType;
			SendFlags = messageSendFlags;
			_safeRW = true;
			_stream.SetLength(0L);
			_stream.Position = 0L;
			_disposedValue = false;
		}

		internal void InitReceive(SteamNetworkingMessage_t message, bool safeReadingAndWriting)
		{
			IntPtr pData = message.m_pData;
			int cbSize = message.m_cbSize;
			if (pData == IntPtr.Zero)
			{
				throw new ArgumentNullException("dataPointer");
			}
			if (cbSize < 2)
			{
				throw new ArgumentOutOfRangeException("dataSize");
			}
			_safeRW = safeReadingAndWriting;
			if (_safeRW)
			{
				if (_stream.Capacity < cbSize)
				{
					_stream.Capacity = cbSize;
				}
				_stream.SetLength(cbSize);
				Marshal.Copy(pData, _stream.GetBuffer(), 0, cbSize);
				_stream.Position = 0L;
			}
			else
			{
				SetupUnsafeReading(pData, cbSize);
			}
			if (!ParseHeader(ref Type))
			{
				throw new ArgumentOutOfRangeException("Type");
			}
			HSteamNetConnection conn = message.m_conn;
			if (conn == HSteamNetConnection.Invalid)
			{
				throw new ArgumentNullException("steamNetConnectionHandle");
			}
			SteamNetworkingIdentity identityPeer = message.m_identityPeer;
			CSteamID steamID = identityPeer.GetSteamID();
			if (steamID == CSteamID.Nil)
			{
				throw new ArgumentNullException("steamNetworkingIdentity");
			}
			SetSenderInformation(conn, steamID);
			_disposedValue = false;
		}

		private unsafe void SetupUnsafeReading(IntPtr dataPointer, int dataSize)
		{
			_unmanagedStream = new UnmanagedMemoryStream((byte*)dataPointer.ToPointer(), dataSize);
			_reader = new NetworkReader(_unmanagedStream);
		}

		private bool ParseHeader(ref MessageType messageType)
		{
			messageType = _reader.ReadMessageType();
			if (messageType == MessageType.None)
			{
				return false;
			}
			return true;
		}

		private void SetSenderInformation(HSteamNetConnection steamNetConnectionHandle, CSteamID steamUserId)
		{
			SteamNetConnectionHandle = steamNetConnectionHandle;
			SteamUserId = steamUserId;
		}

		internal TMsg Deserialize<TMsg>() where TMsg : MessageBase, new()
		{
			if (_reader == null)
			{
				throw new NullReferenceException("_reader");
			}
			TMsg val = new TMsg();
			val.Deserialize(_reader);
			return val;
		}

		internal void Deserialize<TMsg>(TMsg tMsg) where TMsg : MessageBase
		{
			if (_reader == null)
			{
				throw new NullReferenceException("_reader");
			}
			tMsg.Deserialize(_reader);
		}

		internal void Serialize<TMsg>(TMsg tMsg) where TMsg : MessageBase
		{
			if (tMsg == null || _writer == null)
			{
				throw new NullReferenceException("tMsg, _writer");
			}
			_writer.WriteMessageType(Type);
			tMsg.Serialize(_writer);
		}

		internal byte[] GetBuffer()
		{
			if (_stream == null)
			{
				return null;
			}
			return _stream.GetBuffer();
		}

		internal long GetLength()
		{
			if (_stream == null)
			{
				return 0L;
			}
			return _stream.Length;
		}

		internal void Reset()
		{
			SteamUserId = CSteamID.Nil;
			SteamNetConnectionHandle = HSteamNetConnection.Invalid;
			Type = MessageType.None;
			if (!_safeRW && _unmanagedStream != null)
			{
				_unmanagedStream.Dispose();
				_unmanagedStream = null;
				_reader = new NetworkReader(_stream);
				_safeRW = true;
			}
			_stream.SetLength(0L);
			_stream.Position = 0L;
		}

		private void Dispose(bool disposing)
		{
			if (!_disposedValue)
			{
				if (disposing)
				{
					_reader?.Dispose();
					_writer?.Dispose();
					_stream?.Dispose();
					_unmanagedStream?.Dispose();
				}
				_disposedValue = true;
			}
		}

		public void Dispose()
		{
			Dispose(disposing: true);
			GC.SuppressFinalize(this);
		}
	}
}
namespace Megabonk.BonkWithFriends.Networking.Messages.Server
{
	[NetworkMessage(MessageType.AllPlayersReadyForSpawn, MessageSendFlags.ReliableNoNagle)]
	internal sealed class AllPlayersReadyForSpawnMessage : MessageBase
	{
		public int SyncId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(SyncId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			SyncId = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.BossDied, MessageSendFlags.ReliableNoNagle)]
	internal sealed class BossDiedMessage : MessageBase
	{
		internal bool IsLastStage { get; set; }

		internal float HostTime { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(IsLastStage);
			writer.Write(HostTime);
		}

		public override void Deserialize(NetworkReader reader)
		{
			IsLastStage = reader.ReadBoolean();
			HostTime = reader.ReadSingle();
		}
	}
	[NetworkMessage(MessageType.BossLampCharge, MessageSendFlags.ReliableNoNagle)]
	internal sealed class BossLampChargeMessage : MessageBase
	{
		internal int LampId { get; set; }

		internal bool IsStarting { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(LampId);
			writer.Write(IsStarting);
		}

		public override void Deserialize(NetworkReader reader)
		{
			LampId = reader.ReadInt32();
			IsStarting = reader.ReadBoolean();
		}
	}
	[NetworkMessage(MessageType.BossPylonCharge, MessageSendFlags.ReliableNoNagle)]
	internal sealed class BossPylonChargeMessage : MessageBase
	{
		internal int PylonId { get; set; }

		internal bool IsStarting { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(PylonId);
			writer.Write(IsStarting);
		}

		public override void Deserialize(NetworkReader reader)
		{
			PylonId = reader.ReadInt32();
			IsStarting = reader.ReadBoolean();
		}
	}
	[NetworkMessage(MessageType.BossSpawnSync, MessageSendFlags.ReliableNoNagle)]
	internal sealed class BossSpawnSyncMessage : MessageBase
	{
		internal struct BossInfo
		{
			internal uint BossPartId;

			internal Vector3 Position;

			internal float MaxHp;
		}

		internal List<BossInfo> Spawns { get; set; } = new List<BossInfo>();

		public override void Serialize(NetworkWriter writer)
		{
			//IL_0035: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(Spawns.Count);
			foreach (BossInfo spawn in Spawns)
			{
				writer.Write(spawn.BossPartId);
				writer.WriteVector3(spawn.Position);
				writer.Write(spawn.MaxHp);
			}
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_0034: Unknown result type (might be due to invalid IL or missing references)
			//IL_0039: Unknown result type (might be due to invalid IL or missing references)
			Spawns.Clear();
			int num = reader.ReadInt32();
			for (int i = 0; i < num; i++)
			{
				Spawns.Add(new BossInfo
				{
					BossPartId = reader.ReadUInt32(),
					Position = reader.ReadVector3(),
					MaxHp = reader.ReadSingle()
				});
			}
		}
	}
	[NetworkMessage(MessageType.EnemyDamaged, MessageSendFlags.ReliableNoNagle)]
	internal sealed class EnemyDamagedMessage : MessageBase
	{
		internal uint EnemyId { get; set; }

		internal float Damage { get; set; }

		internal int DamageEffect { get; set; }

		internal int DamageBlockedByArmor { get; set; }

		internal string DamageSource { get; set; }

		internal float DamageProcCoefficient { get; set; }

		internal int DamageElement { get; set; }

		internal int DamageFlags { get; set; }

		internal float DamageKnockback { get; set; }

		internal bool DamageIsCrit { get; set; }

		internal ulong AttackerId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(EnemyId);
			writer.Write(Damage);
			writer.Write(DamageEffect);
			writer.Write(DamageBlockedByArmor);
			writer.Write(DamageSource ?? string.Empty);
			writer.Write(DamageProcCoefficient);
			writer.Write(DamageElement);
			writer.Write(DamageFlags);
			writer.Write(DamageKnockback);
			writer.Write(DamageIsCrit);
			writer.Write(AttackerId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			EnemyId = reader.ReadUInt32();
			Damage = reader.ReadSingle();
			DamageEffect = reader.ReadInt32();
			DamageBlockedByArmor = reader.ReadInt32();
			DamageSource = reader.ReadString();
			DamageProcCoefficient = reader.ReadSingle();
			DamageElement = reader.ReadInt32();
			DamageFlags = reader.ReadInt32();
			DamageKnockback = reader.ReadSingle();
			DamageIsCrit = reader.ReadBoolean();
			AttackerId = reader.ReadUInt64();
		}
	}
	[NetworkMessage(MessageType.EnemyDied, MessageSendFlags.ReliableNoNagle)]
	internal sealed class EnemyDiedMessage : MessageBase
	{
		internal uint EnemyId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(EnemyId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			EnemyId = reader.ReadUInt32();
		}
	}
	[NetworkMessage(MessageType.EnemySpawned, MessageSendFlags.ReliableNoNagle)]
	internal sealed class EnemySpawnedMessage : MessageBase
	{
		internal uint EnemyId { get; set; }

		internal int EnemyType { get; set; }

		internal Vector3 Position { get; set; }

		internal Vector3 EulerAngles { get; set; }

		internal Vector2 VelXZ { get; set; }

		internal float MaxHp { get; set; }

		internal int Flags { get; set; }

		internal float extraSizeMultiplier { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			//IL_0032: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(EnemyId);
			writer.Write(EnemyType);
			writer.WriteVector3(Position);
			writer.WriteVector3(EulerAngles);
			writer.WriteVector2(VelXZ);
			writer.Write(MaxHp);
			writer.Write(Flags);
			writer.Write(extraSizeMultiplier);
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			//IL_0032: Unknown result type (might be due to invalid IL or missing references)
			EnemyId = reader.ReadUInt32();
			EnemyType = reader.ReadInt32();
			Position = reader.ReadVector3();
			EulerAngles = reader.ReadVector3();
			VelXZ = reader.ReadVector2();
			MaxHp = reader.ReadSingle();
			Flags = reader.ReadInt32();
			extraSizeMultiplier = reader.ReadSingle();
		}
	}
	[NetworkMessage(MessageType.EnemySpecialAttack, MessageSendFlags.ReliableNoNagle)]
	internal sealed class EnemySpecialAttackMessage : MessageBase
	{
		internal uint EnemyId { get; set; }

		internal string AttackName { get; set; } = string.Empty;

		internal ulong TargetSteamId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(EnemyId);
			writer.Write(AttackName ?? string.Empty);
			writer.Write(TargetSteamId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			EnemyId = reader.ReadUInt32();
			AttackName = reader.ReadString();
			TargetSteamId = reader.ReadUInt64();
		}
	}
	[NetworkMessage(MessageType.EnemyStateBatch, MessageSendFlags.Unreliable)]
	internal sealed class EnemyStateBatchMessage : MessageBase
	{
		internal struct EnemyState
		{
			internal uint EnemyId;

			internal short PosX;

			internal short PosY;

			internal short PosZ;

			internal byte YawQuantized;

			internal sbyte VelX;

			internal sbyte VelZ;

			internal sbyte AngVelQuantized;

			internal ushort Hp;

			internal ushort MaxHp;

			internal int Flags;

			internal float ServerTime;

			internal uint Seq;
		}

		internal List<EnemyState> States { get; set; } = new List<EnemyState>();

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(States.Count);
			foreach (EnemyState state in States)
			{
				writer.Write(state.EnemyId);
				writer.Write(state.PosX);
				writer.Write(state.PosY);
				writer.Write(state.PosZ);
				writer.Write(state.YawQuantized);
				writer.Write(state.VelX);
				writer.Write(state.VelZ);
				writer.Write(state.AngVelQuantized);
				writer.Write(state.Hp);
				writer.Write(state.MaxHp);
				writer.Write(state.Flags);
				writer.Write(state.ServerTime);
				writer.Write(state.Seq);
			}
		}

		public override void Deserialize(NetworkReader reader)
		{
			States.Clear();
			int num = reader.ReadInt32();
			for (int i = 0; i < num; i++)
			{
				States.Add(new EnemyState
				{
					EnemyId = reader.ReadUInt32(),
					PosX = reader.ReadInt16(),
					PosY = reader.ReadInt16(),
					PosZ = reader.ReadInt16(),
					YawQuantized = reader.ReadByte(),
					VelX = reader.ReadSByte(),
					VelZ = reader.ReadSByte(),
					AngVelQuantized = reader.ReadSByte(),
					Hp = reader.ReadUInt16(),
					MaxHp = reader.ReadUInt16(),
					Flags = reader.ReadInt32(),
					ServerTime = reader.ReadSingle(),
					Seq = reader.ReadUInt32()
				});
			}
		}
	}
	[NetworkMessage(MessageType.FinalBossOrbDestroyed, MessageSendFlags.ReliableNoNagle)]
	internal sealed class FinalBossOrbDestroyedMessage : MessageBase
	{
		internal uint OrbId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(OrbId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			OrbId = reader.ReadUInt32();
		}
	}
	[NetworkMessage(MessageType.FinalBossOrbSpawned, MessageSendFlags.ReliableNoNagle)]
	internal sealed class FinalBossOrbSpawnedMessage : MessageBase
	{
		internal OrbType OrbType { get; set; }

		internal ulong TargetId { get; set; }

		internal uint OrbId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write((byte)OrbType);
			writer.Write(TargetId);
			writer.Write(OrbId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			OrbType = (OrbType)reader.ReadByte();
			TargetId = reader.ReadUInt64();
			OrbId = reader.ReadUInt32();
		}
	}
	[NetworkMessage(MessageType.FinalBossOrbsUpdate, MessageSendFlags.Unreliable)]
	internal sealed class FinalBossOrbsUpdateMessage : MessageBase
	{
		internal List<BossOrbModel> Orbs { get; set; } = new List<BossOrbModel>();

		public override void Serialize(NetworkWriter writer)
		{
			//IL_0038: Unknown result type (might be due to invalid IL or missing references)
			writer.Write((ushort)Orbs.Count);
			foreach (BossOrbModel orb in Orbs)
			{
				writer.Write(orb.Id);
				writer.WriteVector3(orb.Position);
			}
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_0035: Unknown result type (might be due to invalid IL or missing references)
			int num = reader.ReadUInt16();
			Orbs = new List<BossOrbModel>(num);
			for (int i = 0; i < num; i++)
			{
				Orbs.Add(new BossOrbModel
				{
					Id = reader.ReadUInt32(),
					Position = reader.ReadVector3()
				});
			}
		}
	}
	[NetworkMessage(MessageType.GameOver, MessageSendFlags.ReliableNoNagle)]
	internal sealed class GameOverMessage : MessageBase
	{
		public override void Serialize(NetworkWriter writer)
		{
		}

		public override void Deserialize(NetworkReader reader)
		{
		}
	}
	[NetworkMessage(MessageType.GameStarted, MessageSendFlags.ReliableNoNagle)]
	internal sealed class GameStartedMessage : MessageBase
	{
		public override void Serialize(NetworkWriter writer)
		{
		}

		public override void Deserialize(NetworkReader reader)
		{
		}
	}
	[NetworkMessage(MessageType.HostWelcome, MessageSendFlags.ReliableNoNagle)]
	internal sealed class HostWelcomeMessage : MessageBase
	{
		internal struct PlayerInfo
		{
			internal ulong SteamUserId;

			internal int Character;
		}

		internal List<PlayerInfo> ExistingPlayers { get; set; } = new List<PlayerInfo>();

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write((ushort)ExistingPlayers.Count);
			foreach (PlayerInfo existingPlayer in ExistingPlayers)
			{
				writer.Write(existingPlayer.SteamUserId);
				writer.Write(existingPlayer.Character);
			}
		}

		public override void Deserialize(NetworkReader reader)
		{
			ExistingPlayers.Clear();
			ushort num = reader.ReadUInt16();
			for (int i = 0; i < num; i++)
			{
				ExistingPlayers.Add(new PlayerInfo
				{
					SteamUserId = reader.ReadUInt64(),
					Character = reader.ReadInt32()
				});
			}
		}
	}
	[NetworkMessage(MessageType.PickupDespawned, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PickupDespawnedMessage : MessageBase
	{
		internal int PickupId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(PickupId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			PickupId = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.PickupSpawned, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PickupSpawnedMessage : MessageBase
	{
		internal int PickupId { get; set; }

		internal int EPickup { get; set; }

		internal Vector3 Position { get; set; }

		internal int Value { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(PickupId);
			writer.Write(EPickup);
			writer.WriteVector3(Position);
			writer.Write(Value);
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			PickupId = reader.ReadInt32();
			EPickup = reader.ReadInt32();
			Position = reader.ReadVector3();
			Value = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.PlayerJoined, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PlayerJoinedMessage : MessageBase
	{
		internal ulong SteamUserId { get; set; }

		internal int Character { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(SteamUserId);
			writer.Write(Character);
		}

		public override void Deserialize(NetworkReader reader)
		{
			SteamUserId = reader.ReadUInt64();
			Character = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.PlayerLeft, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PlayerLeftMessage : MessageBase
	{
		internal ulong SteamUserId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(SteamUserId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			SteamUserId = reader.ReadUInt64();
		}
	}
	[NetworkMessage(MessageType.PlayerRevived, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PlayerRevivedMessage : MessageBase
	{
		internal ulong PlayerSteamId { get; set; }

		internal Vector3 RevivePosition { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(PlayerSteamId);
			writer.WriteVector3(RevivePosition);
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			PlayerSteamId = reader.ReadUInt64();
			RevivePosition = reader.ReadVector3();
		}
	}
	[NetworkMessage(MessageType.ReviveShrineSpawn, MessageSendFlags.ReliableNoNagle)]
	internal sealed class ReviveShrineSpawnMessage : MessageBase
	{
		internal ulong DeadPlayerSteamId { get; set; }

		internal string DeadPlayerName { get; set; }

		internal Vector3 SpawnPosition { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_0023: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(DeadPlayerSteamId);
			writer.Write(DeadPlayerName ?? string.Empty);
			writer.WriteVector3(SpawnPosition);
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			DeadPlayerSteamId = reader.ReadUInt64();
			DeadPlayerName = reader.ReadString();
			SpawnPosition = reader.ReadVector3();
		}
	}
	[NetworkMessage(MessageType.SeedSync, MessageSendFlags.ReliableNoNagle)]
	internal sealed class SeedSyncMessage : MessageBase
	{
		internal int Seed { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(Seed);
		}

		public override void Deserialize(NetworkReader reader)
		{
			Seed = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.ServerHello, MessageSendFlags.ReliableNoNagle)]
	internal sealed class ServerHelloMessage : MessageBase
	{
		internal SemVersion SemVersion { get; private set; }

		public ServerHelloMessage()
		{
		}

		internal ServerHelloMessage(SemVersion semVersion)
		{
			if (semVersion == null)
			{
				throw new ArgumentNullException("semVersion");
			}
			SemVersion = semVersion;
		}

		internal void RetrieveSemVersion()
		{
			if (SemVersion != null)
			{
				throw new InvalidOperationException("SemVersion");
			}
			if (!(Assembly.GetExecutingAssembly() == null))
			{
				BepInPlugin customAttribute = ((MemberInfo)typeof(BonkWithFriendsMod)).GetCustomAttribute<BepInPlugin>();
				if (customAttribute != null && SemVersion.TryParse(((object)customAttribute.Version).ToString(), out var semver))
				{
					SemVersion = semver;
				}
			}
		}

		public override void Serialize(NetworkWriter networkWriter)
		{
			if (SemVersion == null)
			{
				throw new NullReferenceException("SemVersion");
			}
			int major = SemVersion.Major;
			int minor = SemVersion.Minor;
			int patch = SemVersion.Patch;
			networkWriter.Write(major);
			networkWriter.Write(minor);
			networkWriter.Write(patch);
		}

		public override void Deserialize(NetworkReader networkReader)
		{
			int major = networkReader.ReadInt32();
			int minor = networkReader.ReadInt32();
			int patch = networkReader.ReadInt32();
			SemVersion = new SemVersion(major, minor, patch);
		}
	}
	[NetworkMessage(MessageType.ServerReadyForSpawnSync, MessageSendFlags.ReliableNoNagle)]
	internal sealed class ServerReadyForSpawnSyncMessage : MessageBase
	{
		public int SyncId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(SyncId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			SyncId = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.SpawnedObjectBatch, MessageSendFlags.ReliableNoNagle)]
	internal sealed class SpawnedObjectBatchMessage : MessageBase
	{
		internal List<SpawnedObjectData> Spawns { get; set; } = new List<SpawnedObjectData>();

		public override void Serialize(NetworkWriter writer)
		{
			//IL_0041: Unknown result type (might be due to invalid IL or missing references)
			//IL_004d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0059: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(Spawns.Count);
			foreach (SpawnedObjectData spawn in Spawns)
			{
				writer.Write(spawn.Id);
				writer.Write(spawn.PrefabName);
				writer.WriteVector3(spawn.Position);
				writer.WriteQuaternion(spawn.Rotation);
				writer.WriteVector3(spawn.Scale);
				writer.Write(spawn.SubType);
			}
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_0041: Unknown result type (might be due to invalid IL or missing references)
			//IL_0046: Unknown result type (might be due to invalid IL or missing references)
			//IL_004e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0053: Unknown result type (might be due to invalid IL or missing references)
			//IL_005b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0060: Unknown result type (might be due to invalid IL or missing references)
			Spawns.Clear();
			int num = reader.ReadInt32();
			for (int i = 0; i < num; i++)
			{
				Spawns.Add(new SpawnedObjectData
				{
					Id = reader.ReadInt32(),
					PrefabName = reader.ReadString(),
					Position = reader.ReadVector3(),
					Rotation = reader.ReadQuaternion(),
					Scale = reader.ReadVector3(),
					SubType = reader.ReadInt32()
				});
			}
		}
	}
	[NetworkMessage(MessageType.TimelineEvent, MessageSendFlags.ReliableNoNagle)]
	internal sealed class TimelineEventMessage : MessageBase
	{
		internal int EventIndex { get; set; }

		internal float HostTime { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(EventIndex);
			writer.Write(HostTime);
		}

		public override void Deserialize(NetworkReader reader)
		{
			EventIndex = reader.ReadInt32();
			HostTime = reader.ReadSingle();
		}
	}
	[NetworkMessage(MessageType.WaveCue, MessageSendFlags.ReliableNoNagle)]
	internal sealed class WaveCueMessage : MessageBase
	{
		internal int WaveType { get; set; }

		internal float Duration { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(WaveType);
			writer.Write(Duration);
		}

		public override void Deserialize(NetworkReader reader)
		{
			WaveType = reader.ReadInt32();
			Duration = reader.ReadSingle();
		}
	}
	[NetworkMessage(MessageType.WaveFinalCue, MessageSendFlags.ReliableNoNagle)]
	internal sealed class WaveFinalCueMessage : MessageBase
	{
		public override void Serialize(NetworkWriter writer)
		{
		}

		public override void Deserialize(NetworkReader reader)
		{
		}
	}
	[NetworkMessage(MessageType.WavesStopped, MessageSendFlags.ReliableNoNagle)]
	internal sealed class WavesStoppedMessage : MessageBase
	{
		public override void Serialize(NetworkWriter writer)
		{
		}

		public override void Deserialize(NetworkReader reader)
		{
		}
	}
}
namespace Megabonk.BonkWithFriends.Networking.Messages.Shared
{
	[NetworkMessage(MessageType.TimeSyncRequest, MessageSendFlags.ReliableNoNagle)]
	internal sealed class TimeSyncRequestMessage : MessageBase
	{
		internal float ClientSendTime { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(ClientSendTime);
		}

		public override void Deserialize(NetworkReader reader)
		{
			ClientSendTime = reader.ReadSingle();
		}
	}
	[NetworkMessage(MessageType.LoadStage, MessageSendFlags.Reliable)]
	internal sealed class LoadStageMessage : MessageBase
	{
		public int StageIndex { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(StageIndex);
		}

		public override void Deserialize(NetworkReader reader)
		{
			StageIndex = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.TimeSyncResponse, MessageSendFlags.ReliableNoNagle)]
	internal sealed class TimeSyncResponseMessage : MessageBase
	{
		internal float ClientSendTime { get; set; }

		internal float ServerReceiveTime { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(ClientSendTime);
			writer.Write(ServerReceiveTime);
		}

		public override void Deserialize(NetworkReader reader)
		{
			ClientSendTime = reader.ReadSingle();
			ServerReceiveTime = reader.ReadSingle();
		}
	}
	[NetworkMessage(MessageType.Acknowledge, MessageSendFlags.ReliableNoNagle)]
	internal sealed class AcknowledgeMessage : MessageBase
	{
		internal AcknowledgeMessage()
		{
		}

		public override void Serialize(NetworkWriter networkWriter)
		{
		}

		public override void Deserialize(NetworkReader networkReader)
		{
		}
	}
	[NetworkMessage(MessageType.AnimationState, MessageSendFlags.NoNagle)]
	internal sealed class AnimationStateMessage : MessageBase
	{
		internal ulong SteamUserId { get; set; }

		internal byte StateFlags { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(SteamUserId);
			writer.Write(StateFlags);
		}

		public override void Deserialize(NetworkReader reader)
		{
			SteamUserId = reader.ReadUInt64();
			StateFlags = reader.ReadByte();
		}
	}
	[NetworkMessage(MessageType.Chat, MessageSendFlags.ReliableNoNagle)]
	internal sealed class ChatMessage : MessageBase
	{
		public ulong SenderSteamId { get; set; }

		public string Text { get; set; } = string.Empty;

		public ChatMessage()
		{
		}

		public ChatMessage(string text)
		{
			Text = text;
		}

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(SenderSteamId);
			writer.Write(Text ?? string.Empty);
		}

		public override void Deserialize(NetworkReader reader)
		{
			SenderSteamId = reader.ReadUInt64();
			Text = reader.ReadString();
		}
	}
	[NetworkMessage(MessageType.InteractableUsed, MessageSendFlags.ReliableNoNagle)]
	internal sealed class InteractableUsedMessage : MessageBase
	{
		internal ulong PlayerSteamId { get; set; }

		internal int ObjectId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(PlayerSteamId);
			writer.Write(ObjectId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			PlayerSteamId = reader.ReadUInt64();
			ObjectId = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.KeepAlive, MessageSendFlags.ReliableNoNagle)]
	internal sealed class KeepAliveMessage : MessageBase
	{
		internal KeepAliveMessage()
		{
		}

		public override void Serialize(NetworkWriter networkWriter)
		{
		}

		public override void Deserialize(NetworkReader networkReader)
		{
		}
	}
	[NetworkMessage(MessageType.PlayerMovement, MessageSendFlags.NoNagle)]
	internal sealed class PlayerMovementMessage : MessageBase
	{
		internal ulong SteamUserId { get; set; }

		internal Vector3 Position { get; set; }

		internal Quaternion Rotation { get; set; }

		internal Vector3 Velocity { get; set; }

		internal float ServerTime { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(SteamUserId);
			writer.WriteVector3(Position);
			writer.WriteQuaternion(Rotation);
			writer.WriteVector3(Velocity);
			writer.Write(ServerTime);
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			SteamUserId = reader.ReadUInt64();
			Position = reader.ReadVector3();
			Rotation = reader.ReadQuaternion();
			Velocity = reader.ReadVector3();
			ServerTime = reader.ReadSingle();
		}
	}
	[NetworkMessage(MessageType.PlayerState, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PlayerStateMessage : MessageBase
	{
		internal ulong SteamUserId { get; set; }

		internal int Hp { get; set; }

		internal int MaxHp { get; set; }

		internal float Shield { get; set; }

		internal float MaxShield { get; set; }

		internal bool IsDead { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(SteamUserId);
			writer.Write(Hp);
			writer.Write(MaxHp);
			writer.Write(Shield);
			writer.Write(MaxShield);
			writer.Write(IsDead);
		}

		public override void Deserialize(NetworkReader reader)
		{
			SteamUserId = reader.ReadUInt64();
			Hp = reader.ReadInt32();
			MaxHp = reader.ReadInt32();
			Shield = reader.ReadSingle();
			MaxShield = reader.ReadSingle();
			IsDead = reader.ReadBoolean();
		}
	}
	[NetworkMessage(MessageType.ProjectileSpawned, MessageSendFlags.NoNagle)]
	internal sealed class ProjectileSpawnedMessage : MessageBase
	{
		internal uint ProjectileID { get; set; }

		internal ulong SteamUserID { get; set; }

		internal int WeaponType { get; set; }

		internal Vector3 Position { get; set; }

		internal Quaternion Rotation { get; set; }

		internal Vector3 Scale { get; set; }

		internal Vector3? MuzzlePosition { get; set; }

		internal Quaternion? MuzzleRotation { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			//IL_0032: Unknown result type (might be due to invalid IL or missing references)
			//IL_003e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0076: Unknown result type (might be due to invalid IL or missing references)
			//IL_008a: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(ProjectileID);
			writer.Write(SteamUserID);
			writer.Write(WeaponType);
			writer.WriteVector3(Position);
			writer.WriteQuaternion(Rotation);
			writer.WriteVector3(Scale);
			writer.Write(MuzzlePosition.HasValue);
			if (MuzzlePosition.HasValue)
			{
				writer.WriteVector3(MuzzlePosition.Value);
				writer.WriteQuaternion(MuzzleRotation.Value);
			}
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			//IL_0032: Unknown result type (might be due to invalid IL or missing references)
			//IL_003e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0052: Unknown result type (might be due to invalid IL or missing references)
			//IL_0063: Unknown result type (might be due to invalid IL or missing references)
			ProjectileID = reader.ReadUInt32();
			SteamUserID = reader.ReadUInt64();
			WeaponType = reader.ReadInt32();
			Position = reader.ReadVector3();
			Rotation = reader.ReadQuaternion();
			Scale = reader.ReadVector3();
			if (reader.ReadBoolean())
			{
				MuzzlePosition = reader.ReadVector3();
				MuzzleRotation = reader.ReadQuaternion();
			}
		}
	}
	[NetworkMessage(MessageType.ReliableBatch, MessageSendFlags.ReliableNoNagle)]
	internal sealed class ReliableBatchMessage : MessageBase
	{
		private readonly List<MessageBase> _messages;

		internal ReliableBatchMessage()
		{
			_messages = new List<MessageBase>();
		}

		internal ReliableBatchMessage(List<MessageBase> messages)
		{
			if (messages == null || messages.Count <= 0)
			{
				throw new ArgumentNullException("messages");
			}
			_messages = messages;
		}

		public override void Serialize(NetworkWriter networkWriter)
		{
			foreach (MessageBase message in _messages)
			{
				message.Serialize(networkWriter);
			}
		}

		public override void Deserialize(NetworkReader networkReader)
		{
			foreach (MessageBase message in _messages)
			{
				message.Deserialize(networkReader);
			}
		}
	}
	[NetworkMessage(MessageType.StartChargingShrine, MessageSendFlags.ReliableNoNagle)]
	internal sealed class StartChargingShrineMessage : MessageBase
	{
		internal int ShrineObjectId { get; set; }

		internal ulong PlayerSteamId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(ShrineObjectId);
			writer.Write(PlayerSteamId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			ShrineObjectId = reader.ReadInt32();
			PlayerSteamId = reader.ReadUInt64();
		}
	}
	[NetworkMessage(MessageType.StopChargingShrine, MessageSendFlags.ReliableNoNagle)]
	internal sealed class StopChargingShrineMessage : MessageBase
	{
		internal int ShrineObjectId { get; set; }

		internal ulong PlayerSteamId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(ShrineObjectId);
			writer.Write(PlayerSteamId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			ShrineObjectId = reader.ReadInt32();
			PlayerSteamId = reader.ReadUInt64();
		}
	}
	[NetworkMessage(MessageType.UnreliableBatch, MessageSendFlags.NoNagle)]
	internal sealed class UnreliableBatchMessage : MessageBase
	{
		private readonly List<MessageBase> _messages;

		internal UnreliableBatchMessage()
		{
			_messages = new List<MessageBase>();
		}

		internal UnreliableBatchMessage(List<MessageBase> messages)
		{
			if (messages == null || messages.Count <= 0)
			{
				throw new ArgumentNullException("messages");
			}
			_messages = messages;
		}

		public override void Serialize(NetworkWriter networkWriter)
		{
			foreach (MessageBase message in _messages)
			{
				message.Serialize(networkWriter);
			}
		}

		public override void Deserialize(NetworkReader networkReader)
		{
			foreach (MessageBase message in _messages)
			{
				message.Deserialize(networkReader);
			}
		}
	}
	[NetworkMessage(MessageType.WeaponAttackStarted, MessageSendFlags.ReliableNoNagle)]
	internal sealed class WeaponAttackStartedMessage : MessageBase
	{
		internal ulong SteamUserId { get; set; }

		internal int WeaponType { get; set; }

		internal int ProjectileCount { get; set; }

		internal float BurstInterval { get; set; }

		internal float ProjectileSize { get; set; }

		internal Vector3 SpawnPosition { get; set; }

		internal Quaternion SpawnRotation { get; set; }

		internal uint AttackId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_003e: Unknown result type (might be due to invalid IL or missing references)
			//IL_004a: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(SteamUserId);
			writer.Write(WeaponType);
			writer.Write(ProjectileCount);
			writer.Write(BurstInterval);
			writer.Write(ProjectileSize);
			writer.WriteVector3(SpawnPosition);
			writer.WriteQuaternion(SpawnRotation);
			writer.Write(AttackId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_003e: Unknown result type (might be due to invalid IL or missing references)
			//IL_004a: Unknown result type (might be due to invalid IL or missing references)
			SteamUserId = reader.ReadUInt64();
			WeaponType = reader.ReadInt32();
			ProjectileCount = reader.ReadInt32();
			BurstInterval = reader.ReadSingle();
			ProjectileSize = reader.ReadSingle();
			SpawnPosition = reader.ReadVector3();
			SpawnRotation = reader.ReadQuaternion();
			AttackId = reader.ReadUInt32();
		}
	}
	[NetworkMessage(MessageType.WeaponProjectileHit, MessageSendFlags.NoNagle)]
	internal sealed class WeaponProjectileHitMessage : MessageBase
	{
		internal uint AttackId { get; set; }

		internal int ProjectileIndex { get; set; }

		internal Vector3 HitPosition { get; set; }

		internal Vector3 HitNormal { get; set; }

		internal uint TargetId { get; set; }

		internal float Damage { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(AttackId);
			writer.Write(ProjectileIndex);
			writer.WriteVector3(HitPosition);
			writer.WriteVector3(HitNormal);
			writer.Write(TargetId);
			writer.Write(Damage);
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			AttackId = reader.ReadUInt32();
			ProjectileIndex = reader.ReadInt32();
			HitPosition = reader.ReadVector3();
			HitNormal = reader.ReadVector3();
			TargetId = reader.ReadUInt32();
			Damage = reader.ReadSingle();
		}
	}
	[NetworkMessage(MessageType.WeaponProjectileSpawned, MessageSendFlags.NoNagle)]
	internal sealed class WeaponProjectileSpawnedMessage : MessageBase
	{
		internal uint AttackId { get; set; }

		internal int ProjectileIndex { get; set; }

		internal Vector3 Position { get; set; }

		internal Quaternion Rotation { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(AttackId);
			writer.Write(ProjectileIndex);
			writer.WriteVector3(Position);
			writer.WriteQuaternion(Rotation);
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			AttackId = reader.ReadUInt32();
			ProjectileIndex = reader.ReadInt32();
			Position = reader.ReadVector3();
			Rotation = reader.ReadQuaternion();
		}
	}
}
namespace Megabonk.BonkWithFriends.Networking.Messages.Client
{
	[NetworkMessage(MessageType.ClientHello, MessageSendFlags.ReliableNoNagle)]
	internal sealed class ClientHelloMessage : MessageBase
	{
		internal SemVersion SemVersion { get; private set; }

		public ClientHelloMessage()
		{
		}

		internal ClientHelloMessage(SemVersion semVersion)
		{
			if (semVersion == null)
			{
				throw new ArgumentNullException("semVersion");
			}
			SemVersion = semVersion;
		}

		internal void RetrieveSemVersion()
		{
			if (SemVersion != null)
			{
				throw new InvalidOperationException("SemVersion");
			}
			if (!(Assembly.GetExecutingAssembly() == null))
			{
				BepInPlugin customAttribute = ((MemberInfo)typeof(BonkWithFriendsMod)).GetCustomAttribute<BepInPlugin>();
				if (customAttribute != null && SemVersion.TryParse(((object)customAttribute.Version).ToString(), out var semver))
				{
					SemVersion = semver;
				}
			}
		}

		public override void Serialize(NetworkWriter networkWriter)
		{
			if (SemVersion == null)
			{
				throw new NullReferenceException("SemVersion");
			}
			int major = SemVersion.Major;
			int minor = SemVersion.Minor;
			int patch = SemVersion.Patch;
			networkWriter.Write(major);
			networkWriter.Write(minor);
			networkWriter.Write(patch);
		}

		public override void Deserialize(NetworkReader networkReader)
		{
			int major = networkReader.ReadInt32();
			int minor = networkReader.ReadInt32();
			int patch = networkReader.ReadInt32();
			SemVersion = new SemVersion(major, minor, patch);
		}
	}
	[NetworkMessage(MessageType.ClientIntroduce, MessageSendFlags.ReliableNoNagle)]
	internal sealed class ClientIntroduceMessage : MessageBase
	{
		internal int Character { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(Character);
		}

		public override void Deserialize(NetworkReader reader)
		{
			Character = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.PrefabReady, MessageSendFlags.ReliableNoNagle)]
	internal sealed class ClientPrefabsReadyMessage : MessageBase
	{
		public override void Serialize(NetworkWriter networkWriter)
		{
		}

		public override void Deserialize(NetworkReader networkReader)
		{
		}
	}
	[NetworkMessage(MessageType.LevelUp, MessageSendFlags.ReliableNoNagle)]
	internal sealed class LevelUpMessage : MessageBase
	{
		internal int NewLevel { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(NewLevel);
		}

		public override void Deserialize(NetworkReader reader)
		{
			NewLevel = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.PickupCollected, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PickupCollectedMessage : MessageBase
	{
		internal int PickupId { get; set; }

		internal ulong CollectorSteamId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(PickupId);
			writer.Write(CollectorSteamId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			PickupId = reader.ReadInt32();
			CollectorSteamId = reader.ReadUInt64();
		}
	}
	[NetworkMessage(MessageType.PlayerDamaged, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PlayerDamagedMessage : MessageBase
	{
		internal float Damage { get; set; }

		internal int Hp { get; set; }

		internal int MaxHp { get; set; }

		internal float Shield { get; set; }

		internal float MaxShield { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(Damage);
			writer.Write(Hp);
			writer.Write(MaxHp);
			writer.Write(Shield);
			writer.Write(MaxShield);
		}

		public override void Deserialize(NetworkReader reader)
		{
			Damage = reader.ReadSingle();
			Hp = reader.ReadInt32();
			MaxHp = reader.ReadInt32();
			Shield = reader.ReadSingle();
			MaxShield = reader.ReadSingle();
		}
	}
	[NetworkMessage(MessageType.PlayerDied, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PlayerDiedMessage : MessageBase
	{
		internal ulong SteamUserId { get; set; }

		internal Vector3 DeathPosition { get; set; }

		internal string PlayerName { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(SteamUserId);
			writer.WriteVector3(DeathPosition);
			writer.Write(PlayerName ?? string.Empty);
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			SteamUserId = reader.ReadUInt64();
			DeathPosition = reader.ReadVector3();
			PlayerName = reader.ReadString();
		}
	}
	[NetworkMessage(MessageType.PlayerHealed, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PlayerHealedMessage : MessageBase
	{
		internal int HealAmount { get; set; }

		internal int Hp { get; set; }

		internal int MaxHp { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(HealAmount);
			writer.Write(Hp);
			writer.Write(MaxHp);
		}

		public override void Deserialize(NetworkReader reader)
		{
			HealAmount = reader.ReadInt32();
			Hp = reader.ReadInt32();
			MaxHp = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.PlayerReadyForSpawn, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PlayerReadyForSpawnMessage : MessageBase
	{
		public int SyncId { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(SyncId);
		}

		public override void Deserialize(NetworkReader reader)
		{
			SyncId = reader.ReadInt32();
		}
	}
	[NetworkMessage(MessageType.PlayerReviveRequest, MessageSendFlags.ReliableNoNagle)]
	internal sealed class PlayerReviveRequestMessage : MessageBase
	{
		internal ulong DeadPlayerSteamId { get; set; }

		internal Vector3 RevivePosition { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			writer.Write(DeadPlayerSteamId);
			writer.WriteVector3(RevivePosition);
		}

		public override void Deserialize(NetworkReader reader)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			DeadPlayerSteamId = reader.ReadUInt64();
			RevivePosition = reader.ReadVector3();
		}
	}
	[NetworkMessage(MessageType.XpGained, MessageSendFlags.ReliableNoNagle)]
	internal sealed class XpGainedMessage : MessageBase
	{
		internal int XpAmount { get; set; }

		public override void Serialize(NetworkWriter writer)
		{
			writer.Write(XpAmount);
		}

		public override void Deserialize(NetworkReader reader)
		{
			XpAmount = reader.ReadInt32();
		}
	}
}
namespace Megabonk.BonkWithFriends.Networking.Handlers
{
	public static class ChargeShrineSystem
	{
		[NetworkMessageHandler(MessageType.StartChargingShrine)]
		private static void HandleStartChargingShrine(SteamNetworkMessage message)
		{
			StartChargingShrineMessage startChargingShrineMessage = message.Deserialize<StartChargingShrineMessage>();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				if (ChargeShrineState.AddCharger(startChargingShrineMessage.ShrineObjectId, startChargingShrineMessage.PlayerSteamId))
				{
					TriggerShrineEnter(startChargingShrineMessage.ShrineObjectId);
				}
				SteamNetworkServer.Instance?.BroadcastMessage(startChargingShrineMessage);
			}
			else if (ChargeShrineState.AddCharger(startChargingShrineMessage.ShrineObjectId, startChargingShrineMessage.PlayerSteamId))
			{
				TriggerShrineEnter(startChargingShrineMessage.ShrineObjectId);
			}
		}

		[NetworkMessageHandler(MessageType.StopChargingShrine)]
		private static void HandleStopChargingShrine(SteamNetworkMessage message)
		{
			StopChargingShrineMessage stopChargingShrineMessage = message.Deserialize<StopChargingShrineMessage>();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				if (ChargeShrineState.RemoveCharger(stopChargingShrineMessage.ShrineObjectId, stopChargingShrineMessage.PlayerSteamId))
				{
					TriggerShrineExit(stopChargingShrineMessage.ShrineObjectId);
				}
				SteamNetworkServer.Instance?.BroadcastMessage(stopChargingShrineMessage);
			}
			else if (ChargeShrineState.RemoveCharger(stopChargingShrineMessage.ShrineObjectId, stopChargingShrineMessage.PlayerSteamId))
			{
				TriggerShrineExit(stopChargingShrineMessage.ShrineObjectId);
			}
		}

		private static void TriggerShrineEnter(int shrineObjectId)
		{
			GameObject val = MatchContext.Current?.SpawnedObjects.GetObject(shrineObjectId);
			if (!Object.op_Implicit((Object)(object)val))
			{
				return;
			}
			ChargeShrine component = val.GetComponent<ChargeShrine>();
			if (Object.op_Implicit((Object)(object)component))
			{
				MatchContext current = MatchContext.Current;
				if (current != null)
				{
					current.SpawnedObjects.CanSendNetworkMessages = false;
				}
				component.OnTriggerEnter();
				MatchContext current2 = MatchContext.Current;
				if (current2 != null)
				{
					current2.SpawnedObjects.CanSendNetworkMessages = true;
				}
			}
		}

		private static void TriggerShrineExit(int shrineObjectId)
		{
			GameObject val = MatchContext.Current?.SpawnedObjects.GetObject(shrineObjectId);
			if (!Object.op_Implicit((Object)(object)val))
			{
				return;
			}
			ChargeShrine component = val.GetComponent<ChargeShrine>();
			if (Object.op_Implicit((Object)(object)component))
			{
				MatchContext current = MatchContext.Current;
				if (current != null)
				{
					current.SpawnedObjects.CanSendNetworkMessages = false;
				}
				component.OnTriggerExit();
				MatchContext current2 = MatchContext.Current;
				if (current2 != null)
				{
					current2.SpawnedObjects.CanSendNetworkMessages = true;
				}
			}
		}
	}
	public static class HandshakeSystem
	{
		private static SemVersion _localVersion;

		static HandshakeSystem()
		{
			BepInPlugin customAttribute = ((MemberInfo)typeof(BonkWithFriendsMod)).GetCustomAttribute<BepInPlugin>();
			if (customAttribute != null && SemVersion.TryParse(((object)customAttribute.Version).ToString(), out var semver))
			{
				_localVersion = semver;
			}
			else
			{
				_localVersion = new SemVersion(0, 0, 0);
			}
		}

		internal static void SendClientHello()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				ClientHelloMessage tMsg = new ClientHelloMessage(_localVersion);
				SteamNetworkClient.Instance?.SendMessage(tMsg);
			}
		}

		[NetworkMessageHandler(MessageType.ClientHello)]
		private static void HandleClientHello(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SemVersion semVersion = message.Deserialize<ClientHelloMessage>().SemVersion;
				CSteamID steamUserId = message.SteamUserId;
				if (!AreVersionsCompatible(_localVersion, semVersion))
				{
					SteamNetworkServer.Instance?.DisconnectClient(steamUserId, "Version mismatch");
					return;
				}
				ServerHelloMessage tMsg = new ServerHelloMessage(_localVersion);
				SteamNetworkServer.Instance?.SendMessage(tMsg, steamUserId);
			}
		}

		[NetworkMessageHandler(MessageType.ServerHello)]
		private static void HandleServerHello(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				SemVersion semVersion = message.Deserialize<ServerHelloMessage>().SemVersion;
				if (!AreVersionsCompatible(_localVersion, semVersion))
				{
					ModLogger.Error($"[HandshakeSystem] Version mismatch! Client: {_localVersion}, Server: {semVersion}. Disconnecting.");
					ToastNotification.Show($"Version mismatch!\nYour version: {_localVersion}\nHost version: {semVersion}\nPlease update to join.", 5f);
					SteamNetworkLobbyManager.LeaveLobby();
					SteamNetworkManager.DestroyClient();
				}
			}
		}

		private static bool AreVersionsCompatible(SemVersion v1, SemVersion v2)
		{
			if (v1 == null || v2 == null)
			{
				return false;
			}
			if (v1.Major == v2.Major)
			{
				return v1.Minor == v2.Minor;
			}
			return false;
		}
	}
	public static class PlayerAttackSystem
	{
		[NetworkMessageHandler(MessageType.WeaponAttackStarted)]
		private static void HandleWeaponAttackStarted(SteamNetworkMessage message)
		{
			//IL_00bd: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c3: Unknown result type (might be due to invalid IL or missing references)
			WeaponAttackStartedMessage weaponAttackStartedMessage = message.Deserialize<WeaponAttackStartedMessage>();
			ulong num = ((weaponAttackStartedMessage.SteamUserId != 0L) ? weaponAttackStartedMessage.SteamUserId : message.SteamUserId.m_SteamID);
			NetworkedPlayer networkedPlayer = MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(num));
			if (!Object.op_Implicit((Object)(object)networkedPlayer))
			{
				ModLogger.Error($"[PlayerAttackSystem] Managers.MatchContext.Current?.RemotePlayers.GetPlayer returned null for Steam ID: {num}");
				return;
			}
			RemoteAttackController componentInChildren = ((Component)networkedPlayer).GetComponentInChildren<RemoteAttackController>();
			if (!Object.op_Implicit((Object)(object)componentInChildren))
			{
				ModLogger.Error("[PlayerAttackSystem] No RemoteAttackController found on player " + ((Object)((Component)networkedPlayer).gameObject).name);
				return;
			}
			componentInChildren.StartAttack(weaponAttackStartedMessage.AttackId, weaponAttackStartedMessage.WeaponType, weaponAttackStartedMessage.ProjectileCount, weaponAttackStartedMessage.BurstInterval, weaponAttackStartedMessage.ProjectileSize, weaponAttackStartedMessage.SpawnPosition, weaponAttackStartedMessage.SpawnRotation);
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server && weaponAttackStartedMessage.SteamUserId != 0L)
			{
				SteamNetworkServer.Instance?.BroadcastMessageExcept(weaponAttackStartedMessage, message.SteamUserId);
			}
		}

		[NetworkMessageHandler(MessageType.WeaponProjectileSpawned)]
		private static void HandleWeaponProjectileSpawned(SteamNetworkMessage message)
		{
		}

		[NetworkMessageHandler(MessageType.WeaponProjectileHit)]
		private static void HandleWeaponProjectileHit(SteamNetworkMessage message)
		{
		}
	}
	public static class PlayerSystem
	{
		[NetworkMessageHandler(MessageType.PlayerJoined)]
		private static void HandlePlayerJoined(SteamNetworkMessage message)
		{
			message.Deserialize<PlayerJoinedMessage>();
		}

		[NetworkMessageHandler(MessageType.PlayerLeft)]
		private static void HandlePlayerLeft(SteamNetworkMessage message)
		{
			message.Deserialize<PlayerLeftMessage>();
		}

		[NetworkMessageHandler(MessageType.PlayerMovement)]
		private static void HandleMovement(SteamNetworkMessage message)
		{
			//IL_0084: Unknown result type (might be due to invalid IL or missing references)
			//IL_008a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0090: Unknown result type (might be due to invalid IL or missing references)
			PlayerMovementMessage playerMovementMessage = message.Deserialize<PlayerMovementMessage>();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server && playerMovementMessage.SteamUserId != 0L)
			{
				SteamNetworkServer.Instance?.BroadcastMessageExcept(playerMovementMessage, message.SteamUserId);
			}
			ulong ulSteamID = ((playerMovementMessage.SteamUserId != 0L) ? playerMovementMessage.SteamUserId : message.SteamUserId.m_SteamID);
			NetworkedPlayer networkedPlayer = MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(ulSteamID));
			if (Object.op_Implicit((Object)(object)networkedPlayer))
			{
				((Component)networkedPlayer).GetComponentInChildren<RemotePlayerInterpolation>()?.OnRemoteMovementUpdate(playerMovementMessage.Position, playerMovementMessage.Rotation, playerMovementMessage.Velocity, playerMovementMessage.ServerTime);
			}
		}

		[NetworkMessageHandler(MessageType.AnimationState)]
		private static void HandleAnimationState(SteamNetworkMessage message)
		{
			AnimationStateMessage animationStateMessage = message.Deserialize<AnimationStateMessage>();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server && animationStateMessage.SteamUserId != 0L)
			{
				SteamNetworkServer.Instance?.BroadcastMessageExcept(animationStateMessage, message.SteamUserId);
			}
			ulong ulSteamID = ((animationStateMessage.SteamUserId != 0L) ? animationStateMessage.SteamUserId : message.SteamUserId.m_SteamID);
			NetworkedPlayer networkedPlayer = MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(ulSteamID));
			if (Object.op_Implicit((Object)(object)networkedPlayer))
			{
				((Component)networkedPlayer).GetComponentInChildren<RemoteAnimationController>()?.OnAnimationStateUpdate(animationStateMessage.StateFlags);
			}
		}

		[NetworkMessageHandler(MessageType.PlayerState)]
		private static void HandlePlayerState(SteamNetworkMessage message)
		{
			PlayerStateMessage playerStateMessage = message.Deserialize<PlayerStateMessage>();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server && playerStateMessage.SteamUserId != 0L)
			{
				SteamNetworkServer.Instance?.BroadcastMessageExcept(playerStateMessage, message.SteamUserId);
			}
			ulong ulSteamID = ((playerStateMessage.SteamUserId != 0L) ? playerStateMessage.SteamUserId : message.SteamUserId.m_SteamID);
			PlayerState state = new PlayerState
			{
				CurrentHp = playerStateMessage.Hp,
				MaxHp = playerStateMessage.MaxHp,
				Shield = playerStateMessage.Shield,
				MaxShield = playerStateMessage.MaxShield,
				IsDead = playerStateMessage.IsDead
			};
			MatchContext.Current?.RemotePlayers.UpdatePlayerState(new CSteamID(ulSteamID), state);
		}

		private static void HandleXpGained(SteamNetworkMessage message)
		{
			XpGainedMessage xpGainedMessage = message.Deserialize<XpGainedMessage>();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessageExcept(xpGainedMessage, message.SteamUserId);
			}
			if ((Object)(object)MatchContext.Current?.LocalPlayer._myPlayer == (Object)null)
			{
				ModLogger.Error("[XpSync] Cannot add XP - _myPlayer is null!");
				return;
			}
			MatchContext current = MatchContext.Current;
			if (((current != null) ? current.LocalPlayer._myPlayer.inventory : null) == null)
			{
				ModLogger.Error("[XpSync] Cannot add XP - inventory is null!");
				return;
			}
			MatchContext current2 = MatchContext.Current;
			if (((current2 != null) ? current2.LocalPlayer._myPlayer.inventory.playerXp : null) == null)
			{
				ModLogger.Error("[XpSync] Cannot add XP - playerXp is null!");
				return;
			}
			PlayerPatches.SetAddingXpFromNetwork(value: true);
			try
			{
				MatchContext current3 = MatchContext.Current;
				if (current3 != null)
				{
					_ = current3.LocalPlayer._myPlayer.inventory.playerXp.xp;
				}
				MatchContext current4 = MatchContext.Current;
				if (current4 != null)
				{
					current4.LocalPlayer._myPlayer.inventory.playerXp.AddXp(xpGainedMessage.XpAmount);
				}
				MatchContext current5 = MatchContext.Current;
				if (current5 != null)
				{
					_ = current5.LocalPlayer._myPlayer.inventory.playerXp.xp;
				}
			}
			catch (Exception value)
			{
				ModLogger.Error($"[XpSync] Exception adding XP: {value}");
			}
			finally
			{
				PlayerPatches.SetAddingXpFromNetwork(value: false);
			}
		}

		[NetworkMessageHandler(MessageType.PlayerDied)]
		private static void HandlePlayerDied(SteamNetworkMessage message)
		{
			//IL_005e: Unknown result type (might be due to invalid IL or missing references)
			PlayerDiedMessage playerDiedMessage = message.Deserialize<PlayerDiedMessage>();
			PlayerState state = new PlayerState
			{
				IsDead = true
			};
			MatchContext.Current?.RemotePlayers.UpdatePlayerState(new CSteamID(playerDiedMessage.SteamUserId), state);
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				MatchContext.Current?.ReviveShrines.OnPlayerDied(playerDiedMessage.SteamUserId, playerDiedMessage.PlayerName, playerDiedMessage.DeathPosition);
			}
		}

		[NetworkMessageHandler(MessageType.ReviveShrineSpawn)]
		private static void HandleReviveShrineSpawn(SteamNetworkMessage message)
		{
			//IL_0023: Unknown result type (might be due to invalid IL or missing references)
			ReviveShrineSpawnMessage reviveShrineSpawnMessage = message.Deserialize<ReviveShrineSpawnMessage>();
			MatchContext.Current?.ReviveShrines.SpawnShrine(reviveShrineSpawnMessage.DeadPlayerSteamId, reviveShrineSpawnMessage.DeadPlayerName, reviveShrineSpawnMessage.SpawnPosition);
		}

		[NetworkMessageHandler(MessageType.PlayerReviveRequest)]
		private static void HandlePlayerReviveRequest(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				PlayerReviveRequestMessage playerReviveRequestMessage = message.Deserialize<PlayerReviveRequestMessage>();
				ReviveShrine reviveShrine = MatchContext.Current?.ReviveShrines.GetShrine(playerReviveRequestMessage.DeadPlayerSteamId);
				if ((Object)(object)reviveShrine != (Object)null)
				{
					reviveShrine.ProcessRevive();
					MatchContext.Current?.ReviveShrines.RemoveShrine(playerReviveRequestMessage.DeadPlayerSteamId);
				}
			}
		}

		[NetworkMessageHandler(MessageType.PlayerRevived)]
		private static void HandlePlayerRevived(SteamNetworkMessage message)
		{
			PlayerRevivedMessage playerRevivedMessage = message.Deserialize<PlayerRevivedMessage>();
			ReviveShrine reviveShrine = MatchContext.Current?.ReviveShrines.GetShrine(playerRevivedMessage.PlayerSteamId);
			if ((Object)(object)reviveShrine != (Object)null)
			{
				reviveShrine.ExecuteRevive();
				if ((Object)(object)((Component)reviveShrine).gameObject != (Object)null)
				{
					Object.Destroy((Object)(object)((Component)reviveShrine).gameObject);
				}
				MatchContext.Current?.ReviveShrines.RemoveShrine(playerRevivedMessage.PlayerSteamId);
			}
		}

		[NetworkMessageHandler(MessageType.InteractableUsed)]
		private static void HandleInteractableUsed(SteamNetworkMessage steamNetworkMessage)
		{
			InteractableUsedMessage interactableUsedMessage = steamNetworkMessage.Deserialize<InteractableUsedMessage>();
			MatchContext.Current?.SpawnedObjects.HandleObjectUsed(interactableUsedMessage);
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessageExcept(interactableUsedMessage, new CSteamID(interactableUsedMessage.PlayerSteamId));
			}
		}
	}
	public static class SpawnSyncSystem
	{
		[NetworkMessageHandler(MessageType.PlayerReadyForSpawn)]
		private static void HandlePlayerReady(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				PlayerReadyForSpawnMessage playerReadyForSpawnMessage = message.Deserialize<PlayerReadyForSpawnMessage>();
				MatchContext.Current?.SpawnSync.OnClientReadyForSpawn(message.SteamUserId.m_SteamID, playerReadyForSpawnMessage.SyncId);
			}
		}

		[NetworkMessageHandler(MessageType.AllPlayersReadyForSpawn)]
		private static void HandleAllPlayersReady(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				AllPlayersReadyForSpawnMessage allPlayersReadyForSpawnMessage = message.Deserialize<AllPlayersReadyForSpawnMessage>();
				MatchContext.Current?.SpawnSync.OnAllPlayersReadyReceived(allPlayersReadyForSpawnMessage.SyncId);
			}
		}

		[NetworkMessageHandler(MessageType.ServerReadyForSpawnSync)]
		private static void HandleServerSyncStart(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				ServerReadyForSpawnSyncMessage serverReadyForSpawnSyncMessage = message.Deserialize<ServerReadyForSpawnSyncMessage>();
				MatchContext.Current?.SpawnSync.OnServerSyncStartReceived(serverReadyForSpawnSyncMessage.SyncId);
			}
		}
	}
	public static class WorldSystem
	{
		[NetworkMessageHandler(MessageType.GameStarted)]
		private static void HandleGameStarted(SteamNetworkMessage steamNetworkMessage)
		{
			MatchContext.Current?.LocalPlayer.OnGameStarted();
		}

		[NetworkMessageHandler(MessageType.WaveCue)]
		private static void HandleWaveCue(SteamNetworkMessage message)
		{
			//IL_0033: Unknown result type (might be due to invalid IL or missing references)
			//IL_0038: Unknown result type (might be due to invalid IL or missing references)
			//IL_0044: Unknown result type (might be due to invalid IL or missing references)
			//IL_004f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0057: Expected O, but got Unknown
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				WaveCueMessage waveCueMessage = message.Deserialize<WaveCueMessage>();
				if (waveCueMessage.WaveType == 2 && Object.op_Implicit((Object)(object)EnemyManager.Instance) && EnemyManager.Instance.summonerController != null)
				{
					TimelineEvent val = new TimelineEvent
					{
						duration = waveCueMessage.Duration,
						enemies = new List<EEnemy>(),
						eTimelineEvent = (ETimelineEvent)2
					};
					EnemyManager.Instance.summonerController.EventSwarm(val);
				}
			}
		}

		[NetworkMessageHandler(MessageType.WaveFinalCue)]
		private static void HandleWaveFinalCue(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server && Object.op_Implicit((Object)(object)EnemyManager.Instance) && EnemyManager.Instance.summonerController != null)
			{
				EnemyManager.Instance.summonerController.StartFinalSwarm();
			}
		}

		[NetworkMessageHandler(MessageType.TimelineEvent)]
		private static void HandleTimelineEvent(SteamNetworkMessage message)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				message.Deserialize<TimelineEventMessage>();
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.Components
{
	[RegisterTypeInIl2Cpp]
	public class ReviveShrine : MonoBehaviour
	{
		private ulong _deadPlayerSteamId;

		private string _deadPlayerName;

		private GameObject _visualIndicator;

		private GameObject _pulseEffect;

		private GameObject _promptObject;

		private TextMeshPro _promptText;

		private bool _isInteracting;

		private float _interactRadius = 2.5f;

		private float _pulseTimer;

		private Color _baseEmissionColor = Color.cyan * 3f;

		public ulong DeadPlayerSteamId => _deadPlayerSteamId;

		public ReviveShrine(IntPtr ptr)
			: base(ptr)
		{
		}//IL_000c: Unknown result type (might be due to invalid IL or missing references)
		//IL_0016: Unknown result type (might be due to invalid IL or missing references)
		//IL_001b: Unknown result type (might be due to invalid IL or missing references)


		public ReviveShrine()
			: base(ClassInjector.DerivedConstructorPointer<ReviveShrine>())
		{
			//IL_000c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0016: Unknown result type (might be due to invalid IL or missing references)
			//IL_001b: Unknown result type (might be due to invalid IL or missing references)
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		public void Initialize(ulong deadPlayerSteamId, string deadPlayerName)
		{
			_deadPlayerSteamId = deadPlayerSteamId;
			_deadPlayerName = deadPlayerName;
			CreateVisuals();
			CreatePromptUI();
		}

		private void CreateVisuals()
		{
			//IL_002d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0037: Unknown result type (might be due to invalid IL or missing references)
			//IL_004c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0056: Unknown result type (might be due to invalid IL or missing references)
			//IL_013b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0145: Unknown result type (might be due to invalid IL or missing references)
			//IL_015a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0164: Unknown result type (might be due to invalid IL or missing references)
			//IL_009a: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a1: Expected O, but got Unknown
			//IL_00bc: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ce: Unknown result type (might be due to invalid IL or missing references)
			//IL_01ab: Unknown result type (might be due to invalid IL or missing references)
			//IL_01b2: Expected O, but got Unknown
			//IL_01cd: Unknown result type (might be due to invalid IL or missing references)
			//IL_01de: Unknown result type (might be due to invalid IL or missing references)
			//IL_01e8: Unknown result type (might be due to invalid IL or missing references)
			_visualIndicator = GameObject.CreatePrimitive((PrimitiveType)0);
			_visualIndicator.transform.SetParent(((Component)this).transform);
			_visualIndicator.transform.localPosition = Vector3.up * 0.5f;
			_visualIndicator.transform.localScale = Vector3.one * 1.2f;
			Collider component = _visualIndicator.GetComponent<Collider>();
			if ((Object)(object)component != (Object)null)
			{
				Object.Destroy((Object)(object)component);
			}
			Renderer component2 = _visualIndicator.GetComponent<Renderer>();
			if ((Object)(object)component2 != (Object)null)
			{
				Material val = new Material(Shader.Find("Standard"));
				val.SetColor("_Color", new Color(0f, 1f, 1f, 0.8f));
				val.SetColor("_EmissionColor", _baseEmissionColor);
				val.EnableKeyword("_EMISSION");
				val.SetFloat("_Metallic", 0.5f);
				val.SetFloat("_Glossiness", 0.8f);
				component2.material = val;
			}
			_pulseEffect = GameObject.CreatePrimitive((PrimitiveType)0);
			_pulseEffect.transform.SetParent(((Component)this).transform);
			_pulseEffect.transform.localPosition = Vector3.up * 0.5f;
			_pulseEffect.transform.localScale = Vector3.one * 0.8f;
			Collider component3 = _pulseEffect.GetComponent<Collider>();
			if ((Object)(object)component3 != (Object)null)
			{
				Object.Destroy((Object)(object)component3);
			}
			Renderer component4 = _pulseEffect.GetComponent<Renderer>();
			if ((Object)(object)component4 != (Object)null)
			{
				Material val2 = new Material(Shader.Find("Standard"));
				val2.SetColor("_Color", new Color(0f, 1f, 1f, 0.2f));
				val2.SetColor("_EmissionColor", Color.cyan * 1.5f);
				val2.EnableKeyword("_EMISSION");
				val2.SetFloat("_Metallic", 0f);
				val2.SetFloat("_Glossiness", 1f);
				val2.SetFloat("_Mode", 3f);
				val2.SetInt("_SrcBlend", 5);
				val2.SetInt("_DstBlend", 10);
				val2.SetInt("_ZWrite", 0);
				val2.DisableKeyword("_ALPHATEST_ON");
				val2.EnableKeyword("_ALPHABLEND_ON");
				val2.DisableKeyword("_ALPHAPREMULTIPLY_ON");
				val2.renderQueue = 3000;
				component4.material = val2;
			}
		}

		private void CreatePromptUI()
		{
			//IL_0006: Unknown result type (might be due to invalid IL or missing references)
			//IL_0010: Expected O, but got Unknown
			//IL_0031: Unknown result type (might be due to invalid IL or missing references)
			//IL_003b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0050: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c8: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d8: Unknown result type (might be due to invalid IL or missing references)
			//IL_00dd: Unknown result type (might be due to invalid IL or missing references)
			//IL_010c: Unknown result type (might be due to invalid IL or missing references)
			_promptObject = new GameObject("RevivePrompt");
			_promptObject.transform.SetParent(((Component)this).transform);
			_promptObject.transform.localPosition = Vector3.up * 1.5f;
			_promptObject.transform.localRotation = Quaternion.identity;
			_promptObject.AddComponent<Billboard>();
			_promptText = _promptObject.AddComponent<TextMeshPro>();
			((TMP_Text)_promptText).text = "[E] Revive " + _deadPlayerName;
			((TMP_Text)_promptText).fontSize = 8f;
			((TMP_Text)_promptText).alignment = (TextAlignmentOptions)514;
			((TMP_Text)_promptText).verticalAlignment = (VerticalAlignmentOptions)512;
			((Graphic)_promptText).color = Color.white;
			((TMP_Text)_promptText).outlineColor = Color32.op_Implicit(Color.black);
			((TMP_Text)_promptText).outlineWidth = 0.3f;
			((TMP_Text)_promptText).rectTransform.sizeDelta = new Vector2(30f, 10f);
			_promptObject.SetActive(false);
		}

		private void Update()
		{
			//IL_0058: Unknown result type (might be due to invalid IL or missing references)
			//IL_005e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0081: Unknown result type (might be due to invalid IL or missing references)
			if (_isInteracting)
			{
				UpdateInteractingVisuals();
				return;
			}
			_pulseTimer += Time.deltaTime * 2f;
			if ((Object)(object)_pulseEffect != (Object)null)
			{
				float num = 0.8f + Mathf.Sin(_pulseTimer) * 0.2f;
				_pulseEffect.transform.localScale = Vector3.one * num;
			}
			if ((Object)(object)_visualIndicator != (Object)null)
			{
				_visualIndicator.transform.Rotate(Vector3.up, 30f * Time.deltaTime);
			}
			CheckForInteraction();
		}

		private void UpdateInteractingVisuals()
		{
			//IL_0049: Unknown result type (might be due to invalid IL or missing references)
			//IL_004f: Unknown result type (might be due to invalid IL or missing references)
			//IL_009b: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a0: Unknown result type (might be due to invalid IL or missing references)
			//IL_00aa: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b0: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b5: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c1: Unknown result type (might be due to invalid IL or missing references)
			_pulseTimer += Time.deltaTime * 8f;
			if ((Object)(object)_pulseEffect != (Object)null)
			{
				float num = 0.8f + Mathf.Sin(_pulseTimer) * 0.4f;
				_pulseEffect.transform.localScale = Vector3.one * num;
			}
			if ((Object)(object)_visualIndicator != (Object)null)
			{
				Renderer component = _visualIndicator.GetComponent<Renderer>();
				if ((Object)(object)component != (Object)null)
				{
					float num2 = (Mathf.Sin(_pulseTimer * 2f) + 1f) * 0.5f;
					Color val = Color.Lerp(_baseEmissionColor, Color.white * 5f, num2);
					component.material.SetColor("_EmissionColor", val);
				}
			}
		}

		private void CheckForInteraction()
		{
			//IL_0075: Unknown result type (might be due to invalid IL or missing references)
			//IL_0080: Unknown result type (might be due to invalid IL or missing references)
			GameManager instance = GameManager.Instance;
			MyPlayer val = ((instance != null) ? instance.player : null);
			if ((Object)(object)val == (Object)null)
			{
				HidePrompt();
				return;
			}
			PlayerInventory inventory = val.inventory;
			if (inventory != null)
			{
				PlayerHealth playerHealth = inventory.playerHealth;
				if (((playerHealth != null) ? new int?(playerHealth.hp) : ((int?)null)) <= 0)
				{
					HidePrompt();
					return;
				}
			}
			float num = Vector3.Distance(((Component)this).transform.position, ((Component)val).transform.position);
			if (num <= _interactRadius)
			{
				ShowPrompt(num);
				if (Input.GetKeyDown((KeyCode)101))
				{
					TryRevive();
				}
			}
			else
			{
				HidePrompt();
			}
		}

		private void ShowPrompt(float distance)
		{
			if (!((Object)(object)_promptObject == (Object)null))
			{
				_promptObject.SetActive(true);
				float num = 1f - distance / _interactRadius * 0.5f;
				((TMP_Text)_promptText).alpha = Mathf.Clamp01(num);
			}
		}

		private void HidePrompt()
		{
			if ((Object)(object)_promptObject != (Object)null)
			{
				_promptObject.SetActive(false);
			}
		}

		private void TryRevive()
		{
			//IL_0044: Unknown result type (might be due to invalid IL or missing references)
			//IL_0073: Unknown result type (might be due to invalid IL or missing references)
			if (!_isInteracting)
			{
				_isInteracting = true;
				if ((Object)(object)_promptText != (Object)null)
				{
					((TMP_Text)_promptText).text = "Reviving " + _deadPlayerName + "...";
					((Graphic)_promptText).color = Color.cyan;
				}
				if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance.SendMessage(new PlayerReviveRequestMessage
					{
						DeadPlayerSteamId = _deadPlayerSteamId,
						RevivePosition = ((Component)this).transform.position
					});
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					ProcessRevive();
				}
			}
		}

		public void ProcessRevive()
		{
			//IL_0023: Unknown result type (might be due to invalid IL or missing references)
			SteamNetworkServer.Instance?.BroadcastMessage(new PlayerRevivedMessage
			{
				PlayerSteamId = _deadPlayerSteamId,
				RevivePosition = ((Component)this).transform.position
			});
			ExecuteRevive();
			CoroutineRunner.Start(DestroyWithEffect());
		}

		public void ExecuteRevive()
		{
			//IL_004f: Unknown result type (might be due to invalid IL or missing references)
			NetworkedPlayer networkedPlayer = MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(_deadPlayerSteamId));
			if ((Object)(object)networkedPlayer != (Object)null)
			{
				networkedPlayer.State.IsDead = false;
				networkedPlayer.ModelInstance.SetActive(true);
				((Component)networkedPlayer).transform.position = ((Component)this).transform.position;
				networkedPlayer.State.CurrentHp = networkedPlayer.State.MaxHp;
			}
			else if (MatchContext.Current?.LocalPlayer.GetLocalSteamId().m_SteamID == _deadPlayerSteamId)
			{
				ReviveLocalPlayer();
			}
		}

		private void ReviveLocalPlayer()
		{
			//IL_003b: Unknown result type (might be due to invalid IL or missing references)
			GameManager instance = GameManager.Instance;
			MyPlayer val = ((instance != null) ? instance.player : null);
			if ((Object)(object)val == (Object)null)
			{
				ModLogger.Error("[ReviveShrine] Cannot revive - local player not found!");
				return;
			}
			((Component)GameManager.Instance.player).transform.position = ((Component)this).transform.position;
			GameManager.Instance.player.inventory.playerHealth.hp = GameManager.Instance.player.inventory.playerHealth.maxHp;
			PlayerInventory inventory = val.inventory;
			PlayerHealth val2 = ((inventory != null) ? inventory.playerHealth : null);
			if (val2 != null)
			{
				val2.hp = val2.maxHp;
			}
			PlayerCameraPatches.DeactivateSpectatorMode();
			if ((Object)(object)val.playerRenderer != (Object)null)
			{
				((Component)val.playerRenderer).gameObject.SetActive(true);
			}
			MatchContext.Current?.LocalPlayer.SetAliveState();
			((Component)GameManager.Instance.player.playerRenderer).gameObject.SetActive(true);
		}

		private IEnumerator DestroyWithEffect()
		{
			if ((Object)(object)_promptText != (Object)null)
			{
				((TMP_Text)_promptText).text = "Revived!";
				((Graphic)_promptText).color = Color.green;
			}
			float duration = 0.5f;
			float elapsed = 0f;
			while (elapsed < duration)
			{
				elapsed += Time.deltaTime;
				float num = elapsed / duration;
				if ((Object)(object)_visualIndicator != (Object)null)
				{
					_visualIndicator.transform.localScale = Vector3.one * (0.6f + num * 0.5f);
					Renderer component = _visualIndicator.GetComponent<Renderer>();
					if ((Object)(object)component != (Object)null)
					{
						Color color = component.material.color;
						color.a = 1f - num;
						component.material.SetColor("_Color", color);
					}
				}
				if ((Object)(object)_pulseEffect != (Object)null)
				{
					_pulseEffect.transform.localScale = Vector3.one * (0.8f + num * 1f);
				}
				yield return null;
			}
			Object.Destroy((Object)(object)((Component)this).gameObject);
		}

		private void OnDestroy()
		{
			MatchContext.Current?.ReviveShrines.RemoveShrine(_deadPlayerSteamId);
		}

		private void OnDrawGizmos()
		{
			//IL_0000: Unknown result type (might be due to invalid IL or missing references)
			//IL_0010: Unknown result type (might be due to invalid IL or missing references)
			Gizmos.color = Color.cyan;
			Gizmos.DrawWireSphere(((Component)this).transform.position, _interactRadius);
		}
	}
}
namespace Megabonk.BonkWithFriends.Player
{
	[RegisterTypeInIl2Cpp]
	public class PlayerAnimationBroadcaster : MonoBehaviour
	{
		private const float SendInterval = 0.05f;

		private PlayerMovement _playerMovement;

		private bool _componentValid;

		private EMovementState _lastSentState;

		private float _lastSendTime;

		private bool _isInitialized;

		public ulong SteamUserId { get; private set; }

		public void Initialize(ulong steamId)
		{
			SteamUserId = steamId;
			CacheComponents();
			_isInitialized = true;
		}

		private void CacheComponents()
		{
			if (!_componentValid)
			{
				_playerMovement = ((Component)this).GetComponentInParent<PlayerMovement>();
				_componentValid = (Object)(object)_playerMovement != (Object)null;
				if (!_componentValid)
				{
					_ = _isInitialized;
				}
			}
		}

		private void Update()
		{
			if (!_isInitialized)
			{
				return;
			}
			if (!_componentValid)
			{
				CacheComponents();
				if (!_componentValid)
				{
					return;
				}
			}
			if (((Il2CppObjectBase)_playerMovement).WasCollected)
			{
				_componentValid = false;
			}
			else if (!(Time.unscaledTime - _lastSendTime < 0.05f))
			{
				BroadcastStateIfChanged();
			}
		}

		private void BroadcastStateIfChanged()
		{
			//IL_0006: Unknown result type (might be due to invalid IL or missing references)
			//IL_000b: Unknown result type (might be due to invalid IL or missing references)
			//IL_000c: Unknown result type (might be due to invalid IL or missing references)
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0017: Unknown result type (might be due to invalid IL or missing references)
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			//IL_0046: Unknown result type (might be due to invalid IL or missing references)
			EMovementState movementState = _playerMovement.GetMovementState();
			if (movementState != _lastSentState)
			{
				_lastSentState = movementState;
				_lastSendTime = Time.unscaledTime;
				AnimationStateMessage tMsg = new AnimationStateMessage
				{
					SteamUserId = ((SteamNetworkManager.Mode == SteamNetworkMode.Client) ? SteamUserId : 0),
					StateFlags = (byte)movementState
				};
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					SteamNetworkServer.Instance.BroadcastMessage(tMsg);
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance.SendMessage(tMsg);
				}
			}
		}

		private void OnDestroy()
		{
			_playerMovement = null;
			_componentValid = false;
		}
	}
	[RegisterTypeInIl2Cpp]
	public class PlayerMovementBroadcaster : MonoBehaviour
	{
		private const float MinPositionDeltaSqr = 0.0001f;

		private const float MinRotationDelta = 1f;

		private Vector3 _lastSentPosition;

		private Quaternion _lastSentRotation;

		private PlayerMovement _playerMovement;

		private Transform _playerRendererTransform;

		private bool _isInitialized;

		private bool _componentsValid;

		public ulong SteamUserId { get; private set; }

		public void Initialize(ulong steamId)
		{
			//IL_0021: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			//IL_0032: Unknown result type (might be due to invalid IL or missing references)
			//IL_0037: Unknown result type (might be due to invalid IL or missing references)
			SteamUserId = steamId;
			CacheComponents();
			if (_componentsValid)
			{
				_lastSentPosition = ((Component)_playerMovement).transform.position;
				_lastSentRotation = _playerRendererTransform.rotation;
			}
			_isInitialized = true;
		}

		private void CacheComponents()
		{
			if (_componentsValid)
			{
				return;
			}
			_playerMovement = ((Component)this).GetComponentInParent<PlayerMovement>();
			MyPlayer componentInParent = ((Component)this).GetComponentInParent<MyPlayer>();
			if ((Object)(object)componentInParent != (Object)null)
			{
				PlayerRenderer componentInChildren = ((Component)componentInParent).GetComponentInChildren<PlayerRenderer>();
				if ((Object)(object)componentInChildren != (Object)null)
				{
					_playerRendererTransform = ((Component)componentInChildren).transform;
				}
			}
			_componentsValid = (Object)(object)_playerMovement != (Object)null && (Object)(object)_playerRendererTransform != (Object)null;
			if (!_componentsValid)
			{
				_ = _isInitialized;
			}
		}

		private void Update()
		{
			if (!_isInitialized)
			{
				return;
			}
			if (!_componentsValid)
			{
				CacheComponents();
				if (!_componentsValid)
				{
					return;
				}
			}
			BroadcastMovementIfChanged();
		}

		private void BroadcastMovementIfChanged()
		{
			//IL_002d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0032: Unknown result type (might be due to invalid IL or missing references)
			//IL_0039: Unknown result type (might be due to invalid IL or missing references)
			//IL_003e: Unknown result type (might be due to invalid IL or missing references)
			//IL_003f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0041: Unknown result type (might be due to invalid IL or missing references)
			//IL_0046: Unknown result type (might be due to invalid IL or missing references)
			//IL_004b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0054: Unknown result type (might be due to invalid IL or missing references)
			//IL_0056: Unknown result type (might be due to invalid IL or missing references)
			//IL_0077: Unknown result type (might be due to invalid IL or missing references)
			//IL_007c: Unknown result type (might be due to invalid IL or missing references)
			//IL_009f: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a4: Unknown result type (might be due to invalid IL or missing references)
			//IL_0103: Unknown result type (might be due to invalid IL or missing references)
			//IL_010a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0111: Unknown result type (might be due to invalid IL or missing references)
			//IL_014d: Unknown result type (might be due to invalid IL or missing references)
			//IL_014e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0154: Unknown result type (might be due to invalid IL or missing references)
			//IL_0155: Unknown result type (might be due to invalid IL or missing references)
			if (((Il2CppObjectBase)_playerMovement).WasCollected || ((Il2CppObjectBase)_playerRendererTransform).WasCollected)
			{
				_componentsValid = false;
				return;
			}
			Vector3 position = ((Component)_playerMovement).transform.position;
			Quaternion rotation = _playerRendererTransform.rotation;
			Vector3 val = position - _lastSentPosition;
			float sqrMagnitude = ((Vector3)(ref val)).sqrMagnitude;
			float num = Quaternion.Angle(rotation, _lastSentRotation);
			bool num2 = sqrMagnitude > 0.0001f;
			bool flag = num > 1f;
			if (!num2 && !flag)
			{
				return;
			}
			Vector3 velocity = Vector3.zero;
			try
			{
				if ((Object)(object)_playerMovement != (Object)null && !((Il2CppObjectBase)_playerMovement).WasCollected)
				{
					velocity = _playerMovement.GetVelocity();
				}
			}
			catch (Exception)
			{
				_componentsValid = false;
				return;
			}
			MatchContext current = MatchContext.Current;
			float serverTime = ((current != null && current.TimeSync.IsInitialized) ? MatchContext.Current.TimeSync.CurrentServerTime : Time.unscaledTime);
			PlayerMovementMessage tMsg = new PlayerMovementMessage
			{
				SteamUserId = ((SteamNetworkManager.Mode == SteamNetworkMode.Client) ? SteamUserId : 0),
				Position = position,
				Rotation = rotation,
				Velocity = velocity,
				ServerTime = serverTime
			};
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance.BroadcastMessage(tMsg);
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				SteamNetworkClient.Instance.SendMessage(tMsg);
			}
			_lastSentPosition = position;
			_lastSentRotation = rotation;
		}

		private void OnDestroy()
		{
			_playerMovement = null;
			_playerRendererTransform = null;
			_componentsValid = false;
		}
	}
	[RegisterTypeInIl2Cpp]
	public class NameplateController : MonoBehaviour
	{
		public void Initialize(string playerName)
		{
			//IL_000b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0010: Unknown result type (might be due to invalid IL or missing references)
			//IL_0022: Unknown result type (might be due to invalid IL or missing references)
			//IL_0037: Unknown result type (might be due to invalid IL or missing references)
			//IL_0041: Unknown result type (might be due to invalid IL or missing references)
			//IL_0047: Unknown result type (might be due to invalid IL or missing references)
			//IL_0051: Unknown result type (might be due to invalid IL or missing references)
			//IL_007b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0086: Unknown result type (might be due to invalid IL or missing references)
			//IL_008b: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c5: Unknown result type (might be due to invalid IL or missing references)
			GameObject val = new GameObject("Nameplate_" + playerName);
			val.transform.SetParent(((Component)this).transform, false);
			val.transform.localPosition = new Vector3(0f, 5f, 0f);
			val.transform.localRotation = Quaternion.identity;
			val.AddComponent<Billboard>();
			TextMeshPro obj = val.AddComponent<TextMeshPro>();
			((TMP_Text)obj).text = playerName;
			((TMP_Text)obj).fontSize = 12f;
			((TMP_Text)obj).alignment = (TextAlignmentOptions)514;
			((Graphic)obj).color = Color.white;
			((TMP_Text)obj).outlineColor = Color32.op_Implicit(Color.black);
			((TMP_Text)obj).outlineWidth = 0.3f;
			((TMP_Text)obj).alignment = (TextAlignmentOptions)514;
			((TMP_Text)obj).verticalAlignment = (VerticalAlignmentOptions)512;
			((TMP_Text)obj).rectTransform.sizeDelta = new Vector2(50f, 10f);
		}
	}
	[RegisterTypeInIl2Cpp]
	public class RemotePlayerInterpolation : MonoBehaviour
	{
		private struct Snapshot
		{
			public Vector3 Position;

			public Quaternion Rotation;

			public Vector3 Velocity;

			public float ServerTime;
		}

		private readonly List<Snapshot> _snapshots = new List<Snapshot>(16);

		private const int MAX_SNAPSHOTS = 16;

		private const float INTERPOLATION_DELAY = 0.15f;

		private const float MAX_EXTRAPOLATION_TIME = 0.5f;

		private float _lastPacketTime;

		private bool _hasBaseline;

		public Vector3 Velocity { get; private set; }

		private void Awake()
		{
			_hasBaseline = false;
		}

		public void OnRemoteMovementUpdate(Vector3 pos, Quaternion rot, Vector3 vel, float serverTime)
		{
			//IL_001c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0049: Unknown result type (might be due to invalid IL or missing references)
			//IL_004a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0051: Unknown result type (might be due to invalid IL or missing references)
			//IL_0052: Unknown result type (might be due to invalid IL or missing references)
			//IL_0059: Unknown result type (might be due to invalid IL or missing references)
			//IL_005a: Unknown result type (might be due to invalid IL or missing references)
			//IL_002b: Unknown result type (might be due to invalid IL or missing references)
			//IL_002c: Unknown result type (might be due to invalid IL or missing references)
			if (!_hasBaseline || !(serverTime <= _lastPacketTime))
			{
				_lastPacketTime = serverTime;
				Velocity = vel;
				if (!_hasBaseline)
				{
					Teleport(pos, rot);
					_hasBaseline = true;
				}
				_snapshots.Add(new Snapshot
				{
					Position = pos,
					Rotation = rot,
					Velocity = vel,
					ServerTime = serverTime
				});
				if (_snapshots.Count > 16)
				{
					_snapshots.RemoveAt(0);
				}
			}
		}

		public void Teleport(Vector3 pos, Quaternion rot)
		{
			//IL_000b: Unknown result type (might be due to invalid IL or missing references)
			//IL_001c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0023: Unknown result type (might be due to invalid IL or missing references)
			((Component)this).transform.parent.position = pos;
			((Component)this).transform.parent.rotation = rot;
			Velocity = Vector3.zero;
			_snapshots.Clear();
			_hasBaseline = false;
		}

		public void Update()
		{
			//IL_015d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0164: Unknown result type (might be due to invalid IL or missing references)
			//IL_016b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0170: Unknown result type (might be due to invalid IL or missing references)
			//IL_0175: Unknown result type (might be due to invalid IL or missing references)
			//IL_0179: Unknown result type (might be due to invalid IL or missing references)
			//IL_017e: Unknown result type (might be due to invalid IL or missing references)
			//IL_018b: Unknown result type (might be due to invalid IL or missing references)
			//IL_019d: Unknown result type (might be due to invalid IL or missing references)
			//IL_00fc: Unknown result type (might be due to invalid IL or missing references)
			//IL_0102: Unknown result type (might be due to invalid IL or missing references)
			//IL_0109: Unknown result type (might be due to invalid IL or missing references)
			//IL_010e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0111: Unknown result type (might be due to invalid IL or missing references)
			//IL_0117: Unknown result type (might be due to invalid IL or missing references)
			//IL_011e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0123: Unknown result type (might be due to invalid IL or missing references)
			if (!_hasBaseline || _snapshots.Count == 0)
			{
				return;
			}
			MatchContext current = MatchContext.Current;
			float num = ((current != null && current.TimeSync.IsInitialized) ? MatchContext.Current.TimeSync.CurrentServerTime : _lastPacketTime) - 0.15f;
			Snapshot snapshot = _snapshots[0];
			Snapshot snapshot2 = _snapshots[0];
			bool flag = false;
			for (int num2 = _snapshots.Count - 1; num2 >= 0; num2--)
			{
				if (_snapshots[num2].ServerTime <= num)
				{
					snapshot = _snapshots[num2];
					if (num2 + 1 < _snapshots.Count)
					{
						snapshot2 = _snapshots[num2 + 1];
						flag = true;
					}
					break;
				}
			}
			Vector3 position;
			Quaternion rotation;
			if (flag)
			{
				float num3 = snapshot2.ServerTime - snapshot.ServerTime;
				float num4 = 0f;
				if (num3 > 0.0001f)
				{
					num4 = (num - snapshot.ServerTime) / num3;
				}
				position = Vector3.Lerp(snapshot.Position, snapshot2.Position, num4);
				rotation = Quaternion.Slerp(snapshot.Rotation, snapshot2.Rotation, num4);
			}
			else
			{
				Snapshot snapshot3 = _snapshots[_snapshots.Count - 1];
				float num5 = Mathf.Clamp(num - snapshot3.ServerTime, 0f, 0.5f);
				position = snapshot3.Position + snapshot3.Velocity * num5;
				rotation = snapshot3.Rotation;
			}
			((Component)this).transform.parent.position = position;
			((Component)this).transform.parent.rotation = rotation;
		}
	}
}
namespace Megabonk.BonkWithFriends.MonoBehaviours.Player
{
	[RegisterTypeInIl2Cpp]
	public class RemoteAnimationController : MonoBehaviour
	{
		private static readonly int MovingHash = Animator.StringToHash("moving");

		private static readonly int GroundedHash = Animator.StringToHash("grounded");

		private static readonly int JumpingHash = Animator.StringToHash("jumping");

		private static readonly int GrindingHash = Animator.StringToHash("grinding");

		private static readonly int IdleHash = Animator.StringToHash("idle");

		private Animator _animator;

		private EMovementState _currentState = (EMovementState)1;

		public void Initialize(Animator animator)
		{
			_animator = animator;
			((Behaviour)this).enabled = (Object)(object)_animator != (Object)null;
		}

		public void OnAnimationStateUpdate(byte stateFlags)
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_0003: Unknown result type (might be due to invalid IL or missing references)
			//IL_0008: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0014: Unknown result type (might be due to invalid IL or missing references)
			EMovementState val = (EMovementState)stateFlags;
			if (_currentState != val)
			{
				_currentState = val;
				ApplyState(val);
			}
		}

		private void ApplyState(EMovementState state)
		{
			//IL_000f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0011: Invalid comparison between Unknown and I4
			//IL_0014: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			//IL_0038: Unknown result type (might be due to invalid IL or missing references)
			//IL_004b: Unknown result type (might be due to invalid IL or missing references)
			if (!((Object)(object)_animator == (Object)null))
			{
				bool flag = (int)state == 1;
				bool flag2 = ((Enum)state).HasFlag((Enum)(object)(EMovementState)2);
				bool flag3 = ((Enum)state).HasFlag((Enum)(object)(EMovementState)8);
				bool flag4 = ((Enum)state).HasFlag((Enum)(object)(EMovementState)16);
				bool flag5 = ((Enum)state).HasFlag((Enum)(object)(EMovementState)32);
				bool flag6 = flag || flag2 || flag3 || flag5;
				_animator.SetBool(MovingHash, flag2);
				_animator.SetBool(GroundedHash, flag6);
				_animator.SetBool(JumpingHash, flag4);
				_animator.SetBool(GrindingHash, flag3);
				_animator.SetBool(IdleHash, flag);
			}
		}
	}
	[RegisterTypeInIl2Cpp]
	public class RemoteAttackController : MonoBehaviour
	{
		public class RemoteAttackData
		{
			public ulong PlayerId;

			public Vector3 Position;

			public Quaternion Rotation;

			public float Size;
		}

		private static readonly Dictionary<int, RemoteAttackData> _remoteAttacks = new Dictionary<int, RemoteAttackData>();

		private static readonly HashSet<int> _remoteProjectiles = new HashSet<int>();

		private static readonly Dictionary<int, ulong> _projectileOwners = new Dictionary<int, ulong>();

		private static readonly object _lock = new object();

		private ulong _playerId;

		public static bool TryGetRemoteAttackData(WeaponAttack attack, out RemoteAttackData data)
		{
			data = null;
			if ((Object)(object)attack == (Object)null)
			{
				return false;
			}
			lock (_lock)
			{
				return _remoteAttacks.TryGetValue(((Object)attack).GetInstanceID(), out data);
			}
		}

		public static void MarkProjectileAsRemote(ProjectileBase projectile, ulong playerId)
		{
			if ((Object)(object)projectile == (Object)null)
			{
				return;
			}
			lock (_lock)
			{
				int instanceID = ((Object)projectile).GetInstanceID();
				_remoteProjectiles.Add(instanceID);
				_projectileOwners[instanceID] = playerId;
			}
		}

		public static bool IsRemoteProjectile(ProjectileBase projectile)
		{
			if ((Object)(object)projectile == (Object)null)
			{
				return false;
			}
			lock (_lock)
			{
				return _remoteProjectiles.Contains(((Object)projectile).GetInstanceID());
			}
		}

		public static bool TryGetProjectileOwner(ProjectileBase projectile, out ulong playerId)
		{
			playerId = 0uL;
			if ((Object)(object)projectile == (Object)null)
			{
				return false;
			}
			lock (_lock)
			{
				return _projectileOwners.TryGetValue(((Object)projectile).GetInstanceID(), out playerId);
			}
		}

		public static void CleanupRemoteProjectile(ProjectileBase projectile)
		{
			if ((Object)(object)projectile == (Object)null)
			{
				return;
			}
			lock (_lock)
			{
				int instanceID = ((Object)projectile).GetInstanceID();
				_remoteProjectiles.Remove(instanceID);
				_projectileOwners.Remove(instanceID);
			}
		}

		public static void ClearState()
		{
			lock (_lock)
			{
				_remoteAttacks.Clear();
				_remoteProjectiles.Clear();
				_projectileOwners.Clear();
			}
		}

		private void Awake()
		{
			NetworkedPlayer componentInParent = ((Component)this).GetComponentInParent<NetworkedPlayer>();
			if ((Object)(object)componentInParent != (Object)null)
			{
				_playerId = componentInParent.SteamId;
			}
		}

		private void OnDestroy()
		{
		}

		public void StartAttack(uint attackId, int weaponType, int projectileCount, float burstInterval, float projectileSize, Vector3 position, Quaternion rotation)
		{
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_000f: Unknown result type (might be due to invalid IL or missing references)
			if (projectileCount > 0)
			{
				CoroutineRunner.Start(SpawnAttackCoroutine(attackId, (EWeapon)weaponType, projectileCount, burstInterval, projectileSize, position, rotation));
			}
		}

		public void UpdateAttackPosition(uint attackId, Vector3 position, Quaternion rotation)
		{
		}

		private IEnumerator SpawnAttackCoroutine(uint attackId, EWeapon weaponType, int projectileCount, float burstInterval, float projectileSize, Vector3 position, Quaternion rotation)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			//IL_000f: Unknown result type (might be due to invalid IL or missing references)
			//IL_002c: Unknown result type (might be due to invalid IL or missing references)
			//IL_002e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0034: Unknown result type (might be due to invalid IL or missing references)
			//IL_0036: Unknown result type (might be due to invalid IL or missing references)
			yield return null;
			if ((Object)(object)PoolManager.Instance == (Object)null)
			{
				ModLogger.Error("[RemoteAttack] PoolManager not available");
				yield break;
			}
			AlwaysManager instance = AlwaysManager.Instance;
			if ((Object)(object)((instance != null) ? instance.dataManager : null) == (Object)null)
			{
				ModLogger.Error("[RemoteAttack] DataManager not available");
				yield break;
			}
			WeaponData weapon = AlwaysManager.Instance.dataManager.GetWeapon(weaponType);
			if ((Object)(object)weapon == (Object)null)
			{
				ModLogger.Error($"[RemoteAttack] Unknown weapon type: {weaponType}");
				yield break;
			}
			WeaponBase val = new WeaponBase(weapon);
			WeaponSyncPatches.SetWeaponOwner(val, _playerId);
			WeaponAttack attack = PoolManager.Instance.GetAttack(val);
			if ((Object)(object)attack == (Object)null)
			{
				yield break;
			}
			attack.weaponBase = val;
			attack.attackDone = false;
			((Component)attack).transform.SetPositionAndRotation(position, rotation);
			if ((Object)(object)attack.muzzle != (Object)null)
			{
				attack.muzzle.Set(projectileCount, burstInterval);
			}
			RegisterAttack(attack, projectileSize, position, rotation);
			try
			{
				for (int i = 0; i < projectileCount; i++)
				{
					UpdateAttackData(attack, position, rotation, projectileSize);
					attack.SpawnProjectile(i);
					if (i < projectileCount - 1 && burstInterval > 0f)
					{
						yield return (object)new WaitForSeconds(burstInterval);
					}
				}
				attack.attackDone = true;
			}
			finally
			{
				UnregisterAttack(attack);
			}
		}

		private void RegisterAttack(WeaponAttack attack, float projectileSize, Vector3 position, Quaternion rotation)
		{
			//IL_0012: Unknown result type (might be due to invalid IL or missing references)
			//IL_0013: Unknown result type (might be due to invalid IL or missing references)
			//IL_0019: Unknown result type (might be due to invalid IL or missing references)
			//IL_001b: Unknown result type (might be due to invalid IL or missing references)
			RemoteAttackData value = new RemoteAttackData
			{
				PlayerId = _playerId,
				Position = position,
				Rotation = rotation,
				Size = projectileSize
			};
			lock (_lock)
			{
				_remoteAttacks[((Object)attack).GetInstanceID()] = value;
			}
		}

		private void UpdateAttackData(WeaponAttack attack, Vector3 position, Quaternion rotation, float size)
		{
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			//IL_002c: Unknown result type (might be due to invalid IL or missing references)
			//IL_002d: Unknown result type (might be due to invalid IL or missing references)
			lock (_lock)
			{
				if (_remoteAttacks.TryGetValue(((Object)attack).GetInstanceID(), out var value))
				{
					value.Position = position;
					value.Rotation = rotation;
					value.Size = size;
				}
			}
		}

		private void UnregisterAttack(WeaponAttack attack)
		{
			if ((Object)(object)attack == (Object)null)
			{
				return;
			}
			lock (_lock)
			{
				_remoteAttacks.Remove(((Object)attack).GetInstanceID());
			}
		}
	}
	[RegisterTypeInIl2Cpp]
	public class NetworkedPlayer : MonoBehaviour
	{
		public PlayerState State;

		public ulong SteamId { get; private set; }

		public bool IsLocalPlayer { get; private set; }

		public bool IsHost { get; private set; }

		public ECharacter Character { get; private set; }

		public GameObject ModelInstance { get; private set; }

		public Rigidbody CachedRigidbody { get; private set; }

		private PlayerInventory inventory { get; set; }

		public void Initialize(ulong steamId, bool isLocal, bool isHost)
		{
			//IL_0052: Unknown result type (might be due to invalid IL or missing references)
			//IL_0057: Unknown result type (might be due to invalid IL or missing references)
			//IL_0078: Unknown result type (might be due to invalid IL or missing references)
			//IL_007d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0043: Unknown result type (might be due to invalid IL or missing references)
			SteamId = steamId;
			IsLocalPlayer = isLocal;
			IsHost = isHost;
			if (IsLocalPlayer)
			{
				PlayerRenderer componentInChildren = ((Component)this).GetComponentInChildren<PlayerRenderer>();
				if (Object.op_Implicit((Object)(object)componentInChildren) && Object.op_Implicit((Object)(object)componentInChildren.characterData))
				{
					Character = componentInChildren.characterData.eCharacter;
				}
				GameObject val = new GameObject("PlayerMovementBroadcaster");
				val.transform.SetParent(((Component)this).transform);
				val.AddComponent<PlayerMovementBroadcaster>().Initialize(steamId);
				GameObject val2 = new GameObject("PlayerAnimationBroadcaster");
				val2.transform.SetParent(((Component)this).transform);
				val2.AddComponent<PlayerAnimationBroadcaster>().Initialize(steamId);
				_ = IsHost;
			}
		}

		public void SetupVisuals(ECharacter character, ESkinType skinType)
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_0002: Unknown result type (might be due to invalid IL or missing references)
			TryInstantiateCharacterModel(character, skinType);
		}

		private bool TryInstantiateCharacterModel(ECharacter character, ESkinType skinType)
		{
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			//IL_0046: Unknown result type (might be due to invalid IL or missing references)
			//IL_0050: Expected O, but got Unknown
			//IL_0061: Unknown result type (might be due to invalid IL or missing references)
			//IL_0099: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ae: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d8: Unknown result type (might be due to invalid IL or missing references)
			//IL_00e2: Unknown result type (might be due to invalid IL or missing references)
			//IL_0198: Unknown result type (might be due to invalid IL or missing references)
			//IL_019d: Unknown result type (might be due to invalid IL or missing references)
			//IL_01b9: Unknown result type (might be due to invalid IL or missing references)
			//IL_01be: Unknown result type (might be due to invalid IL or missing references)
			//IL_01eb: Unknown result type (might be due to invalid IL or missing references)
			//IL_01f0: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ea: Unknown result type (might be due to invalid IL or missing references)
			//IL_0107: Unknown result type (might be due to invalid IL or missing references)
			//IL_010c: Unknown result type (might be due to invalid IL or missing references)
			try
			{
				if (!Object.op_Implicit((Object)(object)DataManager.Instance) || !Object.op_Implicit((Object)(object)PoolManager.Instance))
				{
					return false;
				}
				CharacterData characterData = DataManager.Instance.GetCharacterData(character);
				ModelInstance = Object.Instantiate<GameObject>(characterData.prefab, ((Component)this).transform);
				inventory = new PlayerInventory(characterData, false);
				((Object)ModelInstance).name = $"{character}_Visual";
				ModelInstance.transform.localPosition = new Vector3(0f, -1.92f, 0f);
				ModelInstance.transform.localRotation = Quaternion.identity;
				ModelInstance.SetActive(true);
				PlayerRenderer val = ModelInstance.AddComponent<PlayerRenderer>();
				val.SetCharacter(characterData, inventory, Vector3.zero);
				if ((int)skinType != 0)
				{
					List<SkinData> skins = DataManager.Instance.GetSkins(character);
					SkinData val2 = null;
					Enumerator<SkinData> enumerator = skins.GetEnumerator();
					while (enumerator.MoveNext())
					{
						SkinData current = enumerator.Current;
						if (current.skinType == skinType)
						{
							val2 = current;
							break;
						}
					}
					if ((Object)(object)val2 != (Object)null)
					{
						val.SetSkin(val2);
						SkinnedMeshRenderer componentInChildren = ModelInstance.GetComponentInChildren<SkinnedMeshRenderer>();
						if ((Object)(object)componentInChildren != (Object)null)
						{
							((Renderer)componentInChildren).sharedMaterials = new Il2CppReferenceArray<Material>(((IEnumerable<Material>)val.activeMaterials).ToArray());
						}
					}
				}
				val.rendererObject.SetActive(false);
				Rigidbody val3 = ModelInstance.AddComponent<Rigidbody>();
				val3.isKinematic = true;
				val3.useGravity = false;
				val3.constraints = (RigidbodyConstraints)112;
				CachedRigidbody = val3;
				GameObject val4 = new GameObject("RemotePlayerInterpolation");
				val4.transform.SetParent(((Component)this).transform);
				val4.AddComponent<RemotePlayerInterpolation>();
				GameObject val5 = new GameObject("RemoteAnimationController");
				val5.transform.SetParent(((Component)this).transform);
				Animator component = ModelInstance.GetComponent<Animator>();
				val5.AddComponent<RemoteAnimationController>().Initialize(component);
				GameObject val6 = new GameObject("RemoteAttackController");
				val6.transform.SetParent(((Component)this).transform);
				val6.AddComponent<RemoteAttackController>();
				string friendPersonaName = SteamFriends.GetFriendPersonaName(new CSteamID(SteamId));
				ModelInstance.AddComponent<NameplateController>().Initialize(friendPersonaName);
				return true;
			}
			catch (Exception)
			{
				return false;
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.MonoBehaviours.Enemies
{
	internal struct BossOrbSnapshot
	{
		public double Timestamp;

		public Vector3 Position;
	}
	internal class BossOrbInterpolator : MonoBehaviour
	{
		private GameObject _gameObject;

		private readonly List<BossOrbSnapshot> _snapshotsBuffer = new List<BossOrbSnapshot>();

		private const float InterpolationDelayMs = 0.05f;

		private const int MaxBufferSize = 200;

		private int _lastUsedSnapshotIndex;

		private void Update()
		{
			if (HasEnoughSnapshots())
			{
				double renderTime = Time.timeAsDouble - 0.05000000074505806;
				PerformInterpolation(renderTime);
				CleanupOldSnapshots(renderTime);
			}
		}

		public void Initialize(GameObject go)
		{
			_gameObject = go;
		}

		public void AddSnapshot(BossOrbSnapshot snapshot)
		{
			_snapshotsBuffer.Add(snapshot);
			if (_snapshotsBuffer.Count > 200)
			{
				_snapshotsBuffer.RemoveAt(0);
				_lastUsedSnapshotIndex = Mathf.Max(0, _lastUsedSnapshotIndex - 1);
			}
		}

		private bool HasEnoughSnapshots()
		{
			return _snapshotsBuffer.Count >= 2;
		}

		private void PerformInterpolation(double renderTime)
		{
			//IL_0057: Unknown result type (might be due to invalid IL or missing references)
			//IL_005d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0063: Unknown result type (might be due to invalid IL or missing references)
			if (FindSnapshotPair(renderTime, out var older, out var newer))
			{
				float num = CalculateInterpolationFactor(renderTime, older.Timestamp, newer.Timestamp);
				num = Mathf.Clamp01(num);
				if (!((Object)(object)_gameObject == (Object)null) && !((Object)(object)_gameObject.transform == (Object)null))
				{
					_gameObject.transform.position = Vector3.Lerp(older.Position, newer.Position, num);
				}
			}
		}

		private bool FindSnapshotPair(double renderTime, out BossOrbSnapshot older, out BossOrbSnapshot newer)
		{
			older = default(BossOrbSnapshot);
			newer = default(BossOrbSnapshot);
			for (int i = Mathf.Max(0, _lastUsedSnapshotIndex); i < _snapshotsBuffer.Count - 1; i++)
			{
				if (_snapshotsBuffer[i].Timestamp <= renderTime && _snapshotsBuffer[i + 1].Timestamp >= renderTime)
				{
					older = _snapshotsBuffer[i];
					newer = _snapshotsBuffer[i + 1];
					_lastUsedSnapshotIndex = i;
					return true;
				}
			}
			if (_snapshotsBuffer.Count >= 2)
			{
				older = _snapshotsBuffer[_snapshotsBuffer.Count - 2];
				newer = _snapshotsBuffer[_snapshotsBuffer.Count - 1];
				_lastUsedSnapshotIndex = _snapshotsBuffer.Count - 2;
				return true;
			}
			return false;
		}

		private float CalculateInterpolationFactor(double renderTime, double olderTime, double newerTime)
		{
			return (float)((renderTime - olderTime) / (newerTime - olderTime));
		}

		private void CleanupOldSnapshots(double renderTime)
		{
			int num = 0;
			double num2 = renderTime - 0.05000000074505806;
			for (int i = 0; i < _snapshotsBuffer.Count - 2 && _snapshotsBuffer[i].Timestamp < num2; i++)
			{
				num++;
			}
			if (num > 0)
			{
				_snapshotsBuffer.RemoveRange(0, num);
				_lastUsedSnapshotIndex = Mathf.Max(0, _lastUsedSnapshotIndex - num);
			}
		}
	}
	[RegisterTypeInIl2Cpp]
	public class TargetSwitcher : MonoBehaviour
	{
		private Enemy _enemy;

		private float _timer;

		private float _delay;

		private float _switchMaxDistance = 100f;

		private Rigidbody _currentTarget;

		private (float min, float max) _switchIntervalRange = (min: 2f, max: 6f);

		private readonly List<RemotePlayerManager.PlayerTarget> _alivePlayers = new List<RemotePlayerManager.PlayerTarget>(16);

		public TargetSwitcher(IntPtr ptr)
			: base(ptr)
		{
		}

		[HideFromIl2Cpp]
		public void Initialize(Enemy enemy, bool pickCloseTarget = false)
		{
			_enemy = enemy;
			ResetTimer();
			if (pickCloseTarget)
			{
				PickClosestTarget();
			}
			else
			{
				PickRandomTarget();
			}
		}

		[HideFromIl2Cpp]
		public void SetSwitchIntervalRange(float minSeconds, float maxSeconds)
		{
			_switchIntervalRange = (min: minSeconds, max: maxSeconds);
		}

		[HideFromIl2Cpp]
		public void SetSwitchMaxDistance(float distance)
		{
			_switchMaxDistance = distance;
		}

		private void Update()
		{
			if ((Object)(object)_enemy == (Object)null || SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			_timer += Time.deltaTime;
			if (_timer >= _delay)
			{
				PickRandomTarget();
				if ((Object)(object)_currentTarget != (Object)null && CanSwitch())
				{
					_enemy.target = _currentTarget;
				}
				ResetTimer();
			}
		}

		[HideFromIl2Cpp]
		private void PickRandomTarget()
		{
			_alivePlayers.Clear();
			MatchContext.Current?.RemotePlayers.FillAllPlayerTargets(_alivePlayers);
			if (_alivePlayers.Count == 0)
			{
				_currentTarget = null;
			}
			else
			{
				_currentTarget = _alivePlayers[Random.Range(0, _alivePlayers.Count)].Rigidbody;
			}
		}

		[HideFromIl2Cpp]
		private void PickClosestTarget()
		{
			//IL_0085: Unknown result type (might be due to invalid IL or missing references)
			//IL_0090: Unknown result type (might be due to invalid IL or missing references)
			_alivePlayers.Clear();
			MatchContext.Current?.RemotePlayers.FillAllPlayerTargets(_alivePlayers);
			if (_alivePlayers.Count == 0)
			{
				_currentTarget = null;
				return;
			}
			float num = float.MaxValue;
			Rigidbody currentTarget = null;
			foreach (RemotePlayerManager.PlayerTarget alivePlayer in _alivePlayers)
			{
				if (!((Object)(object)alivePlayer.Transform == (Object)null) && !((Object)(object)((Component)_enemy).transform == (Object)null))
				{
					float num2 = Vector3.Distance(((Component)_enemy).transform.position, alivePlayer.Transform.position);
					if (num2 < num)
					{
						num = num2;
						currentTarget = alivePlayer.Rigidbody;
					}
				}
			}
			_currentTarget = currentTarget;
		}

		[HideFromIl2Cpp]
		private bool CanSwitch()
		{
			//IL_0041: Unknown result type (might be due to invalid IL or missing references)
			//IL_0051: Unknown result type (might be due to invalid IL or missing references)
			if ((Object)(object)((Component)_enemy).transform == (Object)null || (Object)(object)_currentTarget == (Object)null || (Object)(object)((Component)_currentTarget).transform == (Object)null)
			{
				return false;
			}
			return Vector3.Distance(((Component)_enemy).transform.position, ((Component)_currentTarget).transform.position) <= _switchMaxDistance;
		}

		[HideFromIl2Cpp]
		private void ResetTimer()
		{
			_timer = 0f;
			_delay = Random.Range(_switchIntervalRange.min, _switchIntervalRange.max);
		}
	}
}
namespace Megabonk.BonkWithFriends.MonoBehaviours.Camera
{
	[RegisterTypeInIl2Cpp]
	public class SpectatorCamera : MonoBehaviour
	{
		private class CameraState
		{
			public Vector3 Position;

			public Quaternion Rotation;
		}

		private const float CAMERA_DISTANCE = 10f;

		private const float CAMERA_RADIUS = 0.3f;

		private const float SMOOTH_SPEED = 30f;

		private const float POSITION_SMOOTH = 0.03f;

		private const float PLAYER_FEET_OFFSET = 2.5f;

		private CameraState _originalCameraState;

		private Transform _targetTransform;

		private string _targetPlayerName = "";

		private int _targetIndex = -1;

		private bool _isFollowingTarget;

		private List<NetworkedPlayer> _alivePlayerCache = new List<NetworkedPlayer>();

		private float _currentDistance = 10f;

		private float _yaw;

		private float _pitch = 10f;

		private Vector3 _lastPlayerRotation = Vector3.zero;

		private Vector3 _smoothedTargetPosition = Vector3.zero;

		private GameObject _deathMessageUI;

		private GameObject _spectatorInfoUI;

		private TextMeshProUGUI _deathMessageText;

		private TextMeshProUGUI _spectatorNameText;

		private TextMeshProUGUI _spectatorHintText;

		private bool _isUIInitialized;

		private bool _wasLeftClickPressed;

		private bool _wasRightClickPressed;

		public bool IsFollowingTarget => _isFollowingTarget;

		private void Awake()
		{
		}

		private void OnDestroy()
		{
			ResetToLocalPlayer();
			if (Object.op_Implicit((Object)(object)_deathMessageUI))
			{
				Object.Destroy((Object)(object)_deathMessageUI);
			}
			if (Object.op_Implicit((Object)(object)_spectatorInfoUI))
			{
				Object.Destroy((Object)(object)_spectatorInfoUI);
			}
		}

		private void Update()
		{
			if (_isFollowingTarget)
			{
				HandleInput();
			}
		}

		private void LateUpdate()
		{
			if (_isFollowingTarget && !((Object)(object)_targetTransform == (Object)null))
			{
				GameManager instance = GameManager.Instance;
				object obj;
				if (instance == null)
				{
					obj = null;
				}
				else
				{
					PlayerCamera playerCamera = instance.playerCamera;
					obj = ((playerCamera != null) ? playerCamera.camera : null);
				}
				if (!((Object)obj == (Object)null))
				{
					UpdateCameraPosition();
				}
			}
		}

		public void ActivateSpectatorMode()
		{
			RefreshAlivePlayerCache();
			NetworkedPlayer networkedPlayer = _alivePlayerCache.FirstOrDefault();
			if (!((Object)(object)networkedPlayer == (Object)null))
			{
				SwitchToPlayer(networkedPlayer.SteamId);
			}
		}

		public void ResetToLocalPlayer()
		{
			//IL_0052: Unknown result type (might be due to invalid IL or missing references)
			//IL_0057: Unknown result type (might be due to invalid IL or missing references)
			//IL_005d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0062: Unknown result type (might be due to invalid IL or missing references)
			if (_isFollowingTarget)
			{
				RestoreOriginalCamera();
				GameManager instance = GameManager.Instance;
				PlayerCamera val = ((instance != null) ? instance.playerCamera : null);
				if ((Object)(object)val != (Object)null)
				{
					((Behaviour)val).enabled = true;
				}
				_isFollowingTarget = false;
				_targetTransform = null;
				_targetPlayerName = "";
				_targetIndex = -1;
				_lastPlayerRotation = Vector3.zero;
				_smoothedTargetPosition = Vector3.zero;
				_currentDistance = 10f;
				UpdateUI();
			}
		}

		public void UpdateFromPlayerRotation(Vector3 playerRotation)
		{
			//IL_0009: Unknown result type (might be due to invalid IL or missing references)
			//IL_001c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0078: Unknown result type (might be due to invalid IL or missing references)
			//IL_0079: Unknown result type (might be due to invalid IL or missing references)
			if (_isFollowingTarget)
			{
				float num = playerRotation.y - _lastPlayerRotation.y;
				float num2 = playerRotation.x - _lastPlayerRotation.x;
				if (num > 180f)
				{
					num -= 360f;
				}
				if (num < -180f)
				{
					num += 360f;
				}
				if (num2 > 180f)
				{
					num2 -= 360f;
				}
				if (num2 < -180f)
				{
					num2 += 360f;
				}
				AddRotation(num, num2);
				_lastPlayerRotation = playerRotation;
			}
		}

		private void HandleInput()
		{
			bool mouseButton = Input.GetMouseButton(0);
			bool mouseButton2 = Input.GetMouseButton(1);
			if (mouseButton && !_wasLeftClickPressed)
			{
				PreviousPlayer();
			}
			else if (mouseButton2 && !_wasRightClickPressed)
			{
				NextPlayer();
			}
			_wasLeftClickPressed = mouseButton;
			_wasRightClickPressed = mouseButton2;
		}

		private void NextPlayer()
		{
			RefreshAlivePlayerCache();
			if (_alivePlayerCache.Count != 0)
			{
				_targetIndex++;
				if (_targetIndex >= _alivePlayerCache.Count)
				{
					_targetIndex = 0;
				}
				SwitchToPlayer(_alivePlayerCache[_targetIndex].SteamId);
			}
		}

		private void PreviousPlayer()
		{
			RefreshAlivePlayerCache();
			if (_alivePlayerCache.Count != 0)
			{
				_targetIndex--;
				if (_targetIndex < 0)
				{
					_targetIndex = _alivePlayerCache.Count - 1;
				}
				SwitchToPlayer(_alivePlayerCache[_targetIndex].SteamId);
			}
		}

		private void SwitchToPlayer(ulong steamId)
		{
			//IL_00e4: Unknown result type (might be due to invalid IL or missing references)
			//IL_00e9: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ec: Unknown result type (might be due to invalid IL or missing references)
			//IL_00f9: Unknown result type (might be due to invalid IL or missing references)
			//IL_0148: Unknown result type (might be due to invalid IL or missing references)
			//IL_014d: Unknown result type (might be due to invalid IL or missing references)
			SaveOriginalCamera();
			GameManager instance = GameManager.Instance;
			PlayerCamera val = ((instance != null) ? instance.playerCamera : null);
			if ((Object)(object)val != (Object)null && ((Behaviour)val).enabled)
			{
				((Behaviour)val).enabled = false;
			}
			RefreshAlivePlayerCache();
			NetworkedPlayer networkedPlayer = _alivePlayerCache.FirstOrDefault((NetworkedPlayer p) => p.SteamId == steamId);
			if ((Object)(object)networkedPlayer == (Object)null)
			{
				return;
			}
			string friendPersonaName = SteamFriends.GetFriendPersonaName(new CSteamID(steamId));
			_targetIndex = _alivePlayerCache.IndexOf(networkedPlayer);
			_targetPlayerName = friendPersonaName ?? "";
			_targetTransform = ((Component)networkedPlayer).transform;
			_isFollowingTarget = true;
			GameManager instance2 = GameManager.Instance;
			object obj;
			if (instance2 == null)
			{
				obj = null;
			}
			else
			{
				PlayerCamera playerCamera = instance2.playerCamera;
				obj = ((playerCamera != null) ? playerCamera.camera : null);
			}
			if ((Object)obj != (Object)null)
			{
				Vector3 eulerAngles = ((Component)GameManager.Instance.playerCamera.camera).transform.eulerAngles;
				_yaw = eulerAngles.y;
				_pitch = eulerAngles.x;
				if (_pitch > 180f)
				{
					_pitch -= 360f;
				}
			}
			else
			{
				_yaw = 0f;
				_pitch = 10f;
			}
			_currentDistance = 10f;
			_smoothedTargetPosition = Vector3.zero;
			UpdateUI();
		}

		private void RefreshAlivePlayerCache()
		{
			_alivePlayerCache.Clear();
			foreach (NetworkedPlayer item in MatchContext.Current?.RemotePlayers.GetAllPlayers())
			{
				if ((Object)(object)item != (Object)null && !item.State.IsDead)
				{
					_alivePlayerCache.Add(item);
				}
			}
		}

		private void UpdateCameraPosition()
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_001f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0031: Unknown result type (might be due to invalid IL or missing references)
			//IL_0036: Unknown result type (might be due to invalid IL or missing references)
			//IL_005f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0064: Unknown result type (might be due to invalid IL or missing references)
			//IL_0067: Unknown result type (might be due to invalid IL or missing references)
			//IL_006c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0043: Unknown result type (might be due to invalid IL or missing references)
			//IL_0044: Unknown result type (might be due to invalid IL or missing references)
			//IL_0082: Unknown result type (might be due to invalid IL or missing references)
			//IL_0087: Unknown result type (might be due to invalid IL or missing references)
			//IL_008c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0091: Unknown result type (might be due to invalid IL or missing references)
			//IL_0094: Unknown result type (might be due to invalid IL or missing references)
			//IL_0099: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ca: Unknown result type (might be due to invalid IL or missing references)
			//IL_00cf: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d6: Unknown result type (might be due to invalid IL or missing references)
			//IL_00db: Unknown result type (might be due to invalid IL or missing references)
			//IL_00e0: Unknown result type (might be due to invalid IL or missing references)
			//IL_00e3: Unknown result type (might be due to invalid IL or missing references)
			//IL_00eb: Unknown result type (might be due to invalid IL or missing references)
			Transform transform = ((Component)GameManager.Instance.playerCamera.camera).transform;
			Vector3 position = _targetTransform.position;
			position.y += 2.5f;
			if (_smoothedTargetPosition == Vector3.zero)
			{
				_smoothedTargetPosition = position;
			}
			else
			{
				float num = Mathf.Clamp01(Time.deltaTime / 0.03f);
				_smoothedTargetPosition = Vector3.Lerp(_smoothedTargetPosition, position, num);
			}
			Vector3 val = Quaternion.Euler(_pitch, _yaw, 0f) * Vector3.back;
			float safeDistance = GetSafeDistance(_smoothedTargetPosition, val, 10f);
			float num2 = Mathf.Clamp01(Time.deltaTime * 30f);
			_currentDistance = Mathf.Lerp(_currentDistance, safeDistance, num2);
			Vector3 position2 = _smoothedTargetPosition + val * _currentDistance;
			transform.position = position2;
			transform.LookAt(_smoothedTargetPosition);
		}

		private void AddRotation(float deltaYaw, float deltaPitch)
		{
			_yaw += deltaYaw;
			_pitch += deltaPitch;
			_pitch = Mathf.Clamp(_pitch, -80f, 80f);
		}

		private float GetSafeDistance(Vector3 targetPosition, Vector3 cameraDirection, float desiredDistance)
		{
			//IL_0000: Unknown result type (might be due to invalid IL or missing references)
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_0002: Unknown result type (might be due to invalid IL or missing references)
			//IL_000c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0035: Unknown result type (might be due to invalid IL or missing references)
			//IL_003a: Unknown result type (might be due to invalid IL or missing references)
			Ray val = new Ray(targetPosition, cameraDirection);
			int num = ~LayerMask.op_Implicit(GameManager.Instance.whatIsPlayer);
			RaycastHit[] array = Il2CppArrayBase<RaycastHit>.op_Implicit((Il2CppArrayBase<RaycastHit>)(object)Physics.SphereCastAll(val, 0.3f, desiredDistance, num));
			float num2 = desiredDistance;
			RaycastHit[] array2 = array;
			for (int i = 0; i < array2.Length; i++)
			{
				RaycastHit val2 = array2[i];
				if (!((Object)(object)((RaycastHit)(ref val2)).collider == (Object)null))
				{
					GameObject gameObject = ((Component)((RaycastHit)(ref val2)).collider).gameObject;
					if (!gameObject.CompareTag("MainCamera") && !gameObject.CompareTag("Player") && !gameObject.CompareTag("CameraFade") && !gameObject.CompareTag("CameraIgnore") && !gameObject.CompareTag("Ignore") && !gameObject.CompareTag("Interactable") && !((Object)(object)gameObject.GetComponentInChildren<Enemy>() != (Object)null) && !((RaycastHit)(ref val2)).collider.isTrigger && (!((Object)(object)_targetTransform != (Object)null) || !gameObject.transform.IsChildOf(_targetTransform)) && ((RaycastHit)(ref val2)).distance < num2)
					{
						num2 = ((RaycastHit)(ref val2)).distance;
					}
				}
			}
			return num2;
		}

		private void SaveOriginalCamera()
		{
			//IL_0045: Unknown result type (might be due to invalid IL or missing references)
			//IL_004a: Unknown result type (might be due to invalid IL or missing references)
			//IL_005b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0060: Unknown result type (might be due to invalid IL or missing references)
			if (_originalCameraState == null)
			{
				GameManager instance = GameManager.Instance;
				PlayerCamera val = ((instance != null) ? instance.playerCamera : null);
				if (!((Object)(object)val == (Object)null) && !((Object)(object)val.camera == (Object)null))
				{
					_originalCameraState = new CameraState
					{
						Position = ((Component)val.camera).transform.position,
						Rotation = ((Component)val.camera).transform.rotation
					};
				}
			}
		}

		private void RestoreOriginalCamera()
		{
			//IL_0044: Unknown result type (might be due to invalid IL or missing references)
			//IL_005f: Unknown result type (might be due to invalid IL or missing references)
			if (_originalCameraState != null)
			{
				GameManager instance = GameManager.Instance;
				PlayerCamera val = ((instance != null) ? instance.playerCamera : null);
				if (!((Object)(object)val == (Object)null) && !((Object)(object)val.camera == (Object)null))
				{
					((Component)val.camera).transform.position = _originalCameraState.Position;
					((Component)val.camera).transform.rotation = _originalCameraState.Rotation;
					val.UpdateZoom();
					_originalCameraState = null;
				}
			}
		}

		private void CreateUI()
		{
			//IL_0016: Unknown result type (might be due to invalid IL or missing references)
			//IL_0020: Expected O, but got Unknown
			//IL_0048: Unknown result type (might be due to invalid IL or missing references)
			//IL_005d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0072: Unknown result type (might be due to invalid IL or missing references)
			//IL_0087: Unknown result type (might be due to invalid IL or missing references)
			//IL_009b: Unknown result type (might be due to invalid IL or missing references)
			//IL_00e8: Unknown result type (might be due to invalid IL or missing references)
			//IL_0114: Unknown result type (might be due to invalid IL or missing references)
			//IL_011e: Expected O, but got Unknown
			//IL_0146: Unknown result type (might be due to invalid IL or missing references)
			//IL_015b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0170: Unknown result type (might be due to invalid IL or missing references)
			//IL_0185: Unknown result type (might be due to invalid IL or missing references)
			//IL_0199: Unknown result type (might be due to invalid IL or missing references)
			//IL_01a8: Unknown result type (might be due to invalid IL or missing references)
			//IL_01ae: Expected O, but got Unknown
			//IL_01d6: Unknown result type (might be due to invalid IL or missing references)
			//IL_01eb: Unknown result type (might be due to invalid IL or missing references)
			//IL_0200: Unknown result type (might be due to invalid IL or missing references)
			//IL_0215: Unknown result type (might be due to invalid IL or missing references)
			//IL_0229: Unknown result type (might be due to invalid IL or missing references)
			//IL_0261: Unknown result type (might be due to invalid IL or missing references)
			//IL_0280: Unknown result type (might be due to invalid IL or missing references)
			//IL_0286: Expected O, but got Unknown
			//IL_02ae: Unknown result type (might be due to invalid IL or missing references)
			//IL_02c3: Unknown result type (might be due to invalid IL or missing references)
			//IL_02d8: Unknown result type (might be due to invalid IL or missing references)
			//IL_02ed: Unknown result type (might be due to invalid IL or missing references)
			//IL_0301: Unknown result type (might be due to invalid IL or missing references)
			//IL_0351: Unknown result type (might be due to invalid IL or missing references)
			Transform transform = ((Component)UiManager.Instance.encounterWindows).transform;
			_deathMessageUI = new GameObject("SpectatorDeathMessage");
			_deathMessageUI.transform.SetParent(transform, false);
			RectTransform obj = _deathMessageUI.AddComponent<RectTransform>();
			obj.anchorMin = new Vector2(0.5f, 1f);
			obj.anchorMax = new Vector2(0.5f, 1f);
			obj.pivot = new Vector2(0.5f, 1f);
			obj.anchoredPosition = new Vector2(0f, -50f);
			obj.sizeDelta = new Vector2(800f, 100f);
			_deathMessageText = _deathMessageUI.AddComponent<TextMeshProUGUI>();
			((TMP_Text)_deathMessageText).text = "skill issue, git gud!";
			((TMP_Text)_deathMessageText).fontSize = 72f;
			((TMP_Text)_deathMessageText).fontStyle = (FontStyles)1;
			((Graphic)_deathMessageText).color = Color.red;
			((TMP_Text)_deathMessageText).alignment = (TextAlignmentOptions)514;
			_deathMessageUI.SetActive(false);
			_spectatorInfoUI = new GameObject("SpectatorInfo");
			_spectatorInfoUI.transform.SetParent(transform, false);
			RectTransform obj2 = _spectatorInfoUI.AddComponent<RectTransform>();
			obj2.anchorMin = new Vector2(0.5f, 0f);
			obj2.anchorMax = new Vector2(0.5f, 0f);
			obj2.pivot = new Vector2(0.5f, 0f);
			obj2.anchoredPosition = new Vector2(0f, 20f);
			obj2.sizeDelta = new Vector2(800f, 120f);
			GameObject val = new GameObject("PlayerName");
			val.transform.SetParent(_spectatorInfoUI.transform, false);
			RectTransform obj3 = val.AddComponent<RectTransform>();
			obj3.anchorMin = new Vector2(0f, 1f);
			obj3.anchorMax = new Vector2(1f, 1f);
			obj3.pivot = new Vector2(0.5f, 1f);
			obj3.anchoredPosition = new Vector2(0f, -20f);
			obj3.sizeDelta = new Vector2(0f, 50f);
			_spectatorNameText = val.AddComponent<TextMeshProUGUI>();
			((TMP_Text)_spectatorNameText).fontSize = 36f;
			((TMP_Text)_spectatorNameText).fontStyle = (FontStyles)1;
			((Graphic)_spectatorNameText).color = Color.white;
			((TMP_Text)_spectatorNameText).alignment = (TextAlignmentOptions)514;
			GameObject val2 = new GameObject("Hint");
			val2.transform.SetParent(_spectatorInfoUI.transform, false);
			RectTransform obj4 = val2.AddComponent<RectTransform>();
			obj4.anchorMin = new Vector2(0f, 1f);
			obj4.anchorMax = new Vector2(1f, 1f);
			obj4.pivot = new Vector2(0.5f, 1f);
			obj4.anchoredPosition = new Vector2(0f, -75f);
			obj4.sizeDelta = new Vector2(0f, 30f);
			_spectatorHintText = val2.AddComponent<TextMeshProUGUI>();
			((TMP_Text)_spectatorHintText).text = "Left Click: Previous | Right Click: Next";
			((TMP_Text)_spectatorHintText).fontSize = 24f;
			((Graphic)_spectatorHintText).color = new Color(1f, 1f, 1f, 0.7f);
			((TMP_Text)_spectatorHintText).alignment = (TextAlignmentOptions)514;
			_spectatorInfoUI.SetActive(false);
		}

		private void UpdateUI()
		{
			if (!_isUIInitialized)
			{
				CreateUI();
				_isUIInitialized = true;
			}
			if (_isFollowingTarget)
			{
				_deathMessageUI.SetActive(true);
				_spectatorInfoUI.SetActive(true);
				int count = _alivePlayerCache.Count;
				((TMP_Text)_spectatorNameText).text = $"Spectating: {_targetPlayerName} ({_targetIndex + 1}/{count})";
			}
			else
			{
				_deathMessageUI.SetActive(false);
				_spectatorInfoUI.SetActive(false);
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.Managers
{
	public enum GameLifecycleState
	{
		None,
		InLobby,
		LoadingMap,
		WaitingAtPortal,
		GameStarted,
		GameOver
	}
	public class GameStateManager
	{
		private GameLifecycleState _state;

		public GameLifecycleState State => _state;

		public bool HasGameStarted
		{
			get
			{
				if (_state != GameLifecycleState.GameStarted)
				{
					return _state == GameLifecycleState.GameOver;
				}
				return true;
			}
		}

		public bool IsWaitingAtPortal => _state == GameLifecycleState.WaitingAtPortal;

		public void TransitionTo(GameLifecycleState newState)
		{
			if (_state != newState)
			{
				_state = newState;
			}
		}
	}
	public class MatchContext : IDisposable
	{
		public static MatchContext Current { get; private set; }

		public GameStateManager GameState { get; private set; }

		public PickupSpawnManager Pickups { get; private set; }

		public SpawnSyncManager SpawnSync { get; private set; }

		public SpawnedObjectManager SpawnedObjects { get; private set; }

		public EnemySpawnManager EnemySpawn { get; private set; }

		public HostEnemyManager HostEnemies { get; private set; }

		public RemoteEnemyManager RemoteEnemies { get; private set; }

		public SmartSpatialTargeting SmartSpatial { get; private set; }

		public FinalBossOrbManager FinalBossOrbs { get; private set; }

		public ReviveShrineManager ReviveShrines { get; private set; }

		public LocalPlayerManager LocalPlayer { get; private set; }

		public RemotePlayerManager RemotePlayers { get; private set; }

		public NetworkTimeSync TimeSync { get; private set; }

		public RemotePlayerTransformContext PlayerTransformContext { get; private set; }

		private MatchContext()
		{
			GameState = new GameStateManager();
			Pickups = new PickupSpawnManager();
			SpawnSync = new SpawnSyncManager();
			SpawnedObjects = new SpawnedObjectManager();
			EnemySpawn = new EnemySpawnManager();
			HostEnemies = new HostEnemyManager();
			RemoteEnemies = new RemoteEnemyManager();
			SmartSpatial = new SmartSpatialTargeting();
			FinalBossOrbs = new FinalBossOrbManager();
			ReviveShrines = new ReviveShrineManager();
			LocalPlayer = new LocalPlayerManager();
			RemotePlayers = new RemotePlayerManager();
			TimeSync = new NetworkTimeSync();
			PlayerTransformContext = new RemotePlayerTransformContext();
		}

		public void ClearFloorState()
		{
			Pickups?.Dispose();
			SpawnedObjects?.Dispose();
			HostEnemies?.Dispose();
			RemoteEnemies?.Dispose();
			SmartSpatial?.Dispose();
			FinalBossOrbs?.Dispose();
			ReviveShrines?.Dispose();
			PlayerTransformContext?.Dispose();
			Pickups = new PickupSpawnManager();
			SpawnedObjects = new SpawnedObjectManager();
			HostEnemies = new HostEnemyManager();
			RemoteEnemies = new RemoteEnemyManager();
			SmartSpatial = new SmartSpatialTargeting();
			FinalBossOrbs = new FinalBossOrbManager();
			ReviveShrines = new ReviveShrineManager();
			PlayerTransformContext = new RemotePlayerTransformContext();
		}

		public void Dispose()
		{
			Pickups?.Dispose();
			SpawnSync?.Dispose();
			SpawnedObjects?.Dispose();
			EnemySpawn?.Dispose();
			HostEnemies?.Dispose();
			RemoteEnemies?.Dispose();
			SmartSpatial?.Dispose();
			FinalBossOrbs?.Dispose();
			ReviveShrines?.Dispose();
			LocalPlayer?.Dispose();
			RemotePlayers?.Dispose();
			TimeSync?.Dispose();
			PlayerTransformContext?.Dispose();
		}

		public static void StartNewMatch()
		{
			if (Current != null)
			{
				Current.Dispose();
			}
			Current = new MatchContext();
		}

		public static void EndMatch()
		{
			if (Current != null)
			{
				Current.Dispose();
				Current = null;
			}
			WeaponSyncPatches.OnLeaveLobby();
			RemoteAttackController.ClearState();
			EnemyPatches.EnemyMovement_GetTargetPosition_Patch.ClearCache();
			EnemyPatches.SpawnPositions_Patch.ClearCache();
		}
	}
	public static class PlayerSceneManager
	{
		public static string _pendingSceneToLoad;

		private static object _spawnWaitCoroutine;

		private static bool _localPlayerInitialized;

		static PlayerSceneManager()
		{
			SteamMatchmakingImpl.OnLobbyLeave = (SteamMatchmakingImpl.LobbyLeaveDelegate)Delegate.Combine(SteamMatchmakingImpl.OnLobbyLeave, new SteamMatchmakingImpl.LobbyLeaveDelegate(OnLobbyClosedCleanup));
		}

		private static void OnLobbyClosedCleanup(CSteamID steamLobbyId)
		{
			MatchContext.EndMatch();
		}

		public static bool HasPendingSceneLoad(out string sceneName)
		{
			sceneName = _pendingSceneToLoad;
			return !string.IsNullOrEmpty(sceneName);
		}

		public static void ClearPendingSceneLoad()
		{
			_pendingSceneToLoad = null;
		}

		public static void OnSceneLoaded(string scene)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				if (MatchContext.Current == null)
				{
					MatchContext.StartNewMatch();
				}
				MatchContext.Current?.GameState.TransitionTo(GameLifecycleState.LoadingMap);
				if (SteamNetworkManager.Mode != SteamNetworkMode.None)
				{
					_spawnWaitCoroutine = CoroutineRunner.Start(WaitForAllPlayersReady());
				}
			}
		}

		private static IEnumerator WaitForAllPlayersReady()
		{
			_localPlayerInitialized = false;
			MatchContext.Current?.GameState.TransitionTo(GameLifecycleState.WaitingAtPortal);
			MyTime.Pause();
			SpawnSyncUI.Show();
			MatchContext.Current?.SpawnSync.StartWaiting();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				MatchContext.Current?.SpawnSync.BroadcastSyncStart();
			}
			CoroutineRunner.Start(InitializeLocalPlayerAndSendReady());
			float startTime = Time.realtimeSinceStartup;
			while (true)
			{
				MatchContext current = MatchContext.Current;
				if (current != null && current.SpawnSync?.AreAllPlayersReady() == true && _localPlayerInitialized)
				{
					break;
				}
				SpawnSyncUI.UpdateAnimation(Time.unscaledDeltaTime);
				GameManager instance = GameManager.Instance;
				MyPlayer val = ((instance != null) ? instance.player : null);
				if ((Object)(object)val != (Object)null && (Object)(object)val.playerInput != (Object)null && ((Behaviour)val.playerInput).enabled)
				{
					((Behaviour)val.playerInput).enabled = false;
				}
				if (Time.realtimeSinceStartup - startTime >= 30f)
				{
					break;
				}
				yield return (object)new WaitForSecondsRealtime(0.17f);
			}
			SpawnSyncUI.Hide();
			InitializeRemotePlayers();
			MyTime.Unpause();
			GameManager instance2 = GameManager.Instance;
			MyPlayer val2 = ((instance2 != null) ? instance2.player : null);
			if ((Object)(object)val2 != (Object)null && (Object)(object)val2.playerInput != (Object)null)
			{
				((Behaviour)val2.playerInput).enabled = true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				MatchContext.Current?.TimeSync.Initialize();
			}
			_spawnWaitCoroutine = null;
		}

		private static IEnumerator InitializeLocalPlayerAndSendReady()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				float syncStartTime = Time.realtimeSinceStartup;
				while (true)
				{
					MatchContext current = MatchContext.Current;
					if ((current != null && current.SpawnSync?.HasServerStartedSync() == true) || Time.realtimeSinceStartup - syncStartTime >= 10f)
					{
						break;
					}
					yield return (object)new WaitForSecondsRealtime(0.1f);
				}
				float prefabStartTime = Time.realtimeSinceStartup;
				while (true)
				{
					MatchContext current2 = MatchContext.Current;
					if ((current2 != null && current2.SpawnedObjects.ArePrefabsRegistered()) || Time.realtimeSinceStartup - prefabStartTime >= 10f)
					{
						break;
					}
					yield return (object)new WaitForSecondsRealtime(0.1f);
				}
			}
			yield return MatchContext.Current?.LocalPlayer.AddNetworkedPlayerComponent();
			if (MatchContext.Current?.LocalPlayer.IsInitialized ?? false)
			{
				_localPlayerInitialized = true;
				if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance?.SendMessage(new PlayerReadyForSpawnMessage
					{
						SyncId = (MatchContext.Current?.SpawnSync.CurrentSyncId ?? 0)
					});
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					MatchContext.Current?.SpawnSync.MarkServerReadyIfSolo();
				}
			}
			else
			{
				ModLogger.Error("[SpawnSync] Failed to initialize local player!");
			}
		}

		private static void InitializeRemotePlayers()
		{
			//IL_0070: Unknown result type (might be due to invalid IL or missing references)
			//IL_0076: Unknown result type (might be due to invalid IL or missing references)
			IReadOnlyList<SteamNetworkLobbyMember> members = SteamNetworkLobby.Instance.Members;
			MatchContext.Current?.RemotePlayers.Initialize();
			foreach (SteamNetworkLobbyMember item in members)
			{
				if (!(item.UserId == SteamUser.GetSteamID()))
				{
					if (item.UserId.m_SteamID == 0L)
					{
						ModLogger.Error("[MP] Invalid Steam ID (0) detected! Skipping.");
					}
					else
					{
						MatchContext.Current?.RemotePlayers.OnGameStarted(item.UserId, item.Character, item.SkinType);
					}
				}
			}
			MatchContext.Current?.RemotePlayers.AddMinimapIcons();
		}

		public static void OnSceneUnloaded(string scene)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				if (_spawnWaitCoroutine != null)
				{
					CoroutineRunner.Stop(_spawnWaitCoroutine);
					_spawnWaitCoroutine = null;
				}
				SpawnSyncUI.Destroy();
				MatchContext.EndMatch();
				_localPlayerInitialized = false;
			}
		}
	}
	public class SpawnSyncManager : IDisposable
	{
		private HashSet<ulong> _readyClients = new HashSet<ulong>();

		private bool _allPlayersReady;

		private int _receivedServerSyncId;

		public int CurrentSyncId { get; private set; }

		public bool IsWaitingForPlayers { get; private set; }

		public void Dispose()
		{
			UnsubscribeFromLobbyEvents();
			_readyClients.Clear();
			_allPlayersReady = false;
			IsWaitingForPlayers = false;
		}

		public void StartWaiting()
		{
			CurrentSyncId++;
			IsWaitingForPlayers = true;
			_allPlayersReady = false;
			_readyClients.Clear();
			SubscribeToLobbyEvents();
		}

		private void SubscribeToLobbyEvents()
		{
			if (SteamNetworkLobby.Instance != null)
			{
				SteamNetworkLobby instance = SteamNetworkLobby.Instance;
				instance.OnMemberRemoved = (SteamNetworkLobby.OnMemberRemovedDelegate)Delegate.Combine(instance.OnMemberRemoved, new SteamNetworkLobby.OnMemberRemovedDelegate(OnLobbyMemberRemoved));
			}
		}

		private void UnsubscribeFromLobbyEvents()
		{
			if (SteamNetworkLobby.Instance != null)
			{
				SteamNetworkLobby instance = SteamNetworkLobby.Instance;
				instance.OnMemberRemoved = (SteamNetworkLobby.OnMemberRemovedDelegate)Delegate.Remove(instance.OnMemberRemoved, new SteamNetworkLobby.OnMemberRemovedDelegate(OnLobbyMemberRemoved));
			}
		}

		private void OnLobbyMemberRemoved(SteamNetworkLobby lobby, SteamNetworkLobbyMember member)
		{
			HandlePlayerDisconnected(member.UserId.m_SteamID);
		}

		public bool AreAllPlayersReady()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			return _allPlayersReady;
		}

		public bool HasServerStartedSync()
		{
			return _receivedServerSyncId >= CurrentSyncId;
		}

		public void OnClientReadyForSpawn(ulong clientSteamId, int syncId)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server && syncId == CurrentSyncId)
			{
				_readyClients.Add(clientSteamId);
				int expectedPlayerCount = GetExpectedPlayerCount();
				if (!_allPlayersReady && _readyClients.Count >= expectedPlayerCount)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(new AllPlayersReadyForSpawnMessage
					{
						SyncId = CurrentSyncId
					});
					_allPlayersReady = true;
					IsWaitingForPlayers = false;
				}
			}
		}

		public void OnAllPlayersReadyReceived(int syncId)
		{
			if (syncId >= CurrentSyncId)
			{
				_allPlayersReady = true;
				IsWaitingForPlayers = false;
			}
		}

		public void OnServerSyncStartReceived(int syncId)
		{
			_receivedServerSyncId = syncId;
		}

		public void BroadcastSyncStart()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(new ServerReadyForSpawnSyncMessage
				{
					SyncId = CurrentSyncId
				});
			}
		}

		public void MarkServerReadyIfSolo()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server && GetExpectedPlayerCount() == 0)
			{
				_allPlayersReady = true;
				IsWaitingForPlayers = false;
			}
		}

		public void HandlePlayerDisconnected(ulong steamId)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server && IsWaitingForPlayers)
			{
				_readyClients.Remove(steamId);
				int expectedPlayerCount = GetExpectedPlayerCount();
				if (!_allPlayersReady && expectedPlayerCount > 0 && _readyClients.Count >= expectedPlayerCount)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(new AllPlayersReadyForSpawnMessage
					{
						SyncId = CurrentSyncId
					});
					_allPlayersReady = true;
					IsWaitingForPlayers = false;
				}
			}
		}

		private int GetExpectedPlayerCount()
		{
			if (SteamNetworkLobby.Instance == null)
			{
				return 0;
			}
			return Math.Max(0, SteamNetworkLobby.Instance.MemberCount - 1);
		}
	}
}
namespace Megabonk.BonkWithFriends.Managers.Server
{
	public class NetworkTimeSync : IDisposable
	{
		private const int SYNC_SAMPLE_COUNT = 8;

		private const float STEADY_INTERVAL = 2f;

		private const float BURST_INTERVAL = 0.1f;

		private const float MAX_ACCEPTABLE_RTT = 1f;

		private readonly float[] _offsetSamples = new float[8];

		private readonly float[] _sortBuffer = new float[8];

		private int _sampleIndex;

		private int _sampleCount;

		private float _smoothedOffset;

		private bool _isInitialized;

		private float _nextSyncRequestTime;

		public float CurrentServerTime => Time.unscaledTime - _smoothedOffset;

		public bool IsInitialized => _isInitialized;

		public void Initialize()
		{
			Dispose();
			_nextSyncRequestTime = Time.unscaledTime;
		}

		public void Update()
		{
			MatchContext current = MatchContext.Current;
			if (current != null && current.LocalPlayer.IsInitialized)
			{
				float unscaledTime = Time.unscaledTime;
				if (unscaledTime >= _nextSyncRequestTime)
				{
					RequestTimeSync(unscaledTime);
					float num = ((_sampleCount < 8) ? 0.1f : 2f);
					_nextSyncRequestTime = unscaledTime + num;
				}
			}
		}

		private void RequestTimeSync(float now)
		{
			if (SteamNetworkClient.Instance != null)
			{
				TimeSyncRequestMessage tMsg = new TimeSyncRequestMessage
				{
					ClientSendTime = now
				};
				SteamNetworkClient.Instance.SendMessage(tMsg);
			}
		}

		public void ProcessTimeSyncResponse(float serverTime, float clientSendTime)
		{
			float unscaledTime = Time.unscaledTime;
			float num = unscaledTime - clientSendTime;
			if (!(num > 1f))
			{
				float num2 = unscaledTime - (serverTime + num * 0.5f);
				_offsetSamples[_sampleIndex] = num2;
				_sampleIndex = (_sampleIndex + 1) % 8;
				bool num3 = !_isInitialized;
				if (_sampleCount < 8)
				{
					_sampleCount++;
				}
				float smoothedOffset = _smoothedOffset;
				_smoothedOffset = CalculateMedianOffset();
				_isInitialized = true;
				if (!num3)
				{
					Mathf.Abs(_smoothedOffset - smoothedOffset);
					_ = 0.1f;
				}
			}
		}

		private float CalculateMedianOffset()
		{
			if (_sampleCount == 0)
			{
				return 0f;
			}
			if (_sampleCount == 1)
			{
				return _offsetSamples[0];
			}
			Array.Copy(_offsetSamples, 0, _sortBuffer, 0, _sampleCount);
			Array.Sort(_sortBuffer, 0, _sampleCount);
			int num = _sampleCount / 2;
			if ((_sampleCount & 1) == 0)
			{
				return (_sortBuffer[num - 1] + _sortBuffer[num]) * 0.5f;
			}
			return _sortBuffer[num];
		}

		public void Dispose()
		{
			_sampleIndex = 0;
			_sampleCount = 0;
			_smoothedOffset = 0f;
			_isInitialized = false;
			_nextSyncRequestTime = 0f;
			Array.Clear(_offsetSamples, 0, _offsetSamples.Length);
			Array.Clear(_sortBuffer, 0, _sortBuffer.Length);
		}
	}
}
namespace Megabonk.BonkWithFriends.Managers.Revive
{
	public class ReviveShrineManager : IDisposable
	{
		private readonly Dictionary<ulong, ReviveShrine> _activeShrines = new Dictionary<ulong, ReviveShrine>();

		public int ActiveShrineCount => _activeShrines.Count;

		public void OnPlayerDied(ulong steamId, string playerName, Vector3 deathPosition)
		{
			//IL_0027: Unknown result type (might be due to invalid IL or missing references)
			//IL_0035: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(new ReviveShrineSpawnMessage
				{
					DeadPlayerSteamId = steamId,
					DeadPlayerName = playerName,
					SpawnPosition = deathPosition
				});
				SpawnShrine(steamId, playerName, deathPosition);
			}
			else
			{
				_ = SteamNetworkManager.Mode;
				_ = 2;
			}
		}

		public void SpawnShrine(ulong deadPlayerSteamId, string deadPlayerName, Vector3 position)
		{
			//IL_0010: Unknown result type (might be due to invalid IL or missing references)
			//IL_0011: Unknown result type (might be due to invalid IL or missing references)
			//IL_0016: Unknown result type (might be due to invalid IL or missing references)
			//IL_003c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0041: Unknown result type (might be due to invalid IL or missing references)
			//IL_0047: Unknown result type (might be due to invalid IL or missing references)
			if (!_activeShrines.ContainsKey(deadPlayerSteamId))
			{
				Vector3 position2 = FindGroundPosition(position);
				GameObject val = new GameObject($"ReviveShrine_{deadPlayerSteamId}");
				val.transform.position = position2;
				ReviveShrine reviveShrine = val.AddComponent<ReviveShrine>();
				reviveShrine.Initialize(deadPlayerSteamId, deadPlayerName);
				_activeShrines[deadPlayerSteamId] = reviveShrine;
			}
		}

		private Vector3 FindGroundPosition(Vector3 position)
		{
			//IL_0000: Unknown result type (might be due to invalid IL or missing references)
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_0030: Unknown result type (might be due to invalid IL or missing references)
			//IL_0031: Unknown result type (might be due to invalid IL or missing references)
			//IL_003b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0040: Unknown result type (might be due to invalid IL or missing references)
			//IL_0045: Unknown result type (might be due to invalid IL or missing references)
			//IL_0016: Unknown result type (might be due to invalid IL or missing references)
			//IL_001b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			//IL_002a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0074: Unknown result type (might be due to invalid IL or missing references)
			//IL_005a: Unknown result type (might be due to invalid IL or missing references)
			//IL_005f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0069: Unknown result type (might be due to invalid IL or missing references)
			//IL_006e: Unknown result type (might be due to invalid IL or missing references)
			RaycastHit val = default(RaycastHit);
			if (Physics.Raycast(position, Vector3.down, ref val, 100f))
			{
				return ((RaycastHit)(ref val)).point + Vector3.up * 0.5f;
			}
			if (Physics.Raycast(position + Vector3.up * 10f, Vector3.down, ref val, 110f))
			{
				return ((RaycastHit)(ref val)).point + Vector3.up * 0.5f;
			}
			return position;
		}

		public ReviveShrine GetShrine(ulong deadPlayerSteamId)
		{
			_activeShrines.TryGetValue(deadPlayerSteamId, out var value);
			return value;
		}

		public void RemoveShrine(ulong deadPlayerSteamId)
		{
			_activeShrines.Remove(deadPlayerSteamId);
		}

		public void Dispose()
		{
			foreach (ReviveShrine value in _activeShrines.Values)
			{
				if ((Object)(object)value != (Object)null && (Object)(object)((Component)value).gameObject != (Object)null)
				{
					Object.Destroy((Object)(object)((Component)value).gameObject);
				}
			}
			_activeShrines.Clear();
		}
	}
}
namespace Megabonk.BonkWithFriends.Managers.Player
{
	public class LocalPlayerManager : IDisposable
	{
		private class LocalPlayerStateManager
		{
			private const float STATE_BROADCAST_RATE = 0.1f;

			private uint _nextAttackId = 1u;

			private float _lastStateBroadcastTime;

			private bool _stateDirty;

			public NetworkedPlayer Player { get; }

			public ulong SteamUserId { get; }

			public MyPlayer MyPlayer { get; set; }

			public bool IsGameActive { get; set; }

			public PlayerState State { get; private set; }

			public LocalPlayerStateManager(NetworkedPlayer player, ulong steamUserId)
			{
				Player = player ?? throw new ArgumentNullException("player");
				SteamUserId = steamUserId;
				State = default(PlayerState);
				IsGameActive = false;
			}

			public uint GetNextAttackId()
			{
				return _nextAttackId++;
			}

			public void ClearAttackState()
			{
				_nextAttackId = 1u;
			}

			public void UpdateHp(int newHp)
			{
				if (State.CurrentHp != newHp)
				{
					PlayerState state = State;
					state.CurrentHp = newHp;
					State = state;
					_stateDirty = true;
				}
			}

			public void UpdateMaxHp(int newMaxHp)
			{
				if (State.MaxHp != newMaxHp)
				{
					PlayerState state = State;
					state.MaxHp = newMaxHp;
					State = state;
					_stateDirty = true;
				}
			}

			public void UpdateShield(float newShield)
			{
				if (!Mathf.Approximately(State.Shield, newShield))
				{
					PlayerState state = State;
					state.Shield = newShield;
					State = state;
					_stateDirty = true;
				}
			}

			public void UpdateMaxShield(float newMaxShield)
			{
				if (!Mathf.Approximately(State.MaxShield, newMaxShield))
				{
					PlayerState state = State;
					state.MaxShield = newMaxShield;
					State = state;
					_stateDirty = true;
				}
			}

			public void UpdateLevel(int newLevel)
			{
				if (State.Level != newLevel)
				{
					PlayerState state = State;
					state.Level = newLevel;
					State = state;
					_stateDirty = true;
				}
			}

			public void UpdateXp(int newXp)
			{
				if (State.Xp != newXp)
				{
					PlayerState state = State;
					state.Xp = newXp;
					State = state;
					_stateDirty = true;
				}
			}

			public void UpdateDeath(bool isDead)
			{
				if (State.IsDead != isDead)
				{
					PlayerState state = State;
					state.IsDead = isDead;
					State = state;
					_stateDirty = true;
				}
			}

			public bool ShouldBroadcastState(float currentTime, bool forceImmediate)
			{
				if (forceImmediate)
				{
					return true;
				}
				if (currentTime - _lastStateBroadcastTime >= 0.1f)
				{
					return _stateDirty;
				}
				return false;
			}

			public void MarkStateBroadcasted(float currentTime)
			{
				_lastStateBroadcastTime = currentTime;
				_stateDirty = false;
			}
		}

		private LocalPlayerStateManager _state;

		public bool IsInitialized => _state != null;

		public NetworkedPlayer LocalPlayer
		{
			get
			{
				if (_state == null)
				{
					ModLogger.Error("[LocalPlayerManager] Accessed LocalPlayer before initialization!");
					return null;
				}
				return _state.Player;
			}
		}

		public PlayerState LocalPlayerState => _state?.State ?? default(PlayerState);

		public bool IsGameActive => _state?.IsGameActive ?? false;

		public MyPlayer _myPlayer => _state?.MyPlayer;

		private void OnLobbyEntered(SteamNetworkLobby steamNetworkLobby)
		{
		}

		private void OnLobbyLeft(SteamNetworkLobby steamNetworkLobby)
		{
			OnGameEnded();
			Dispose();
		}

		public void Initialize(NetworkedPlayer localPlayer, ulong steamUserId)
		{
			if (_state != null)
			{
				Dispose();
			}
			if ((Object)(object)localPlayer == (Object)null)
			{
				throw new ArgumentNullException("localPlayer");
			}
			if (steamUserId == 0L)
			{
				throw new ArgumentException("Invalid Steam ID (0)", "steamUserId");
			}
			_state = new LocalPlayerStateManager(localPlayer, steamUserId);
		}

		public void Dispose()
		{
			if (_state != null)
			{
				NetworkedPlayer player = _state.Player;
				_state = null;
				if ((Object)(object)player != (Object)null)
				{
					Object.Destroy((Object)(object)player);
				}
			}
		}

		public void OnGameStarted()
		{
			//IL_0041: Unknown result type (might be due to invalid IL or missing references)
			//IL_0046: Unknown result type (might be due to invalid IL or missing references)
			//IL_0057: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d5: Unknown result type (might be due to invalid IL or missing references)
			//IL_00da: Unknown result type (might be due to invalid IL or missing references)
			//IL_0097: Unknown result type (might be due to invalid IL or missing references)
			//IL_009c: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a3: Unknown result type (might be due to invalid IL or missing references)
			//IL_00aa: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b3: Expected O, but got Unknown
			if (SteamNetworkLobby.Instance == null)
			{
				ModLogger.Error("[LocalPlayerManager] SteamNetworkLobby.Instance is null in OnGameStarted!");
				return;
			}
			if (_state == null)
			{
				ModLogger.Error("[LocalPlayerManager] OnGameStarted called before initialization!");
				return;
			}
			_state.IsGameActive = true;
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				EMap map = SteamNetworkLobby.Instance.Map;
				int tier = SteamNetworkLobby.Instance.Tier;
				MapData map2 = DataManager.Instance.GetMap(map);
				StageData val = ((Il2CppArrayBase<StageData>)(object)map2.stages)[tier];
				ChallengeData val2 = ((IEnumerable<ChallengeData>)val.challenges).FirstOrDefault((Func<ChallengeData, bool>)((ChallengeData c) => ((Object)c).name == SteamNetworkLobby.Instance.ChallengeName));
				RunConfig val3 = new RunConfig
				{
					mapData = map2,
					stageData = val,
					mapTierIndex = tier
				};
				if ((Object)(object)val2 != (Object)null)
				{
					val3.challenge = val2;
				}
				MapController.StartNewMap(val3);
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				Scene activeScene = SceneManager.GetActiveScene();
				_ = ((Scene)(ref activeScene)).name;
			}
			GameStatePatches.PrintGeneratedMapList();
		}

		public void OnGameEnded()
		{
			if (_state != null)
			{
				_state.IsGameActive = false;
			}
		}

		public void Clear()
		{
			OnGameEnded();
			Dispose();
		}

		public IEnumerator AddNetworkedPlayerComponent()
		{
			MyPlayer val = null;
			if (Object.op_Implicit((Object)(object)GameManager.Instance))
			{
				val = GameManager.Instance.GetPlayer();
			}
			if ((Object)(object)val == (Object)null)
			{
				ModLogger.Error("[LocalPlayerManager] Failed to get MyPlayer from GameManager");
				yield break;
			}
			try
			{
				NetworkedPlayer networkedPlayer = ((Component)val).gameObject.AddComponent<NetworkedPlayer>();
				if (Object.op_Implicit((Object)(object)networkedPlayer))
				{
					ulong steamID = SteamManager.Instance.CurrentUserId.m_SteamID;
					networkedPlayer.Initialize(steamID, isLocal: true, SteamNetworkManager.Mode == SteamNetworkMode.Server);
					Initialize(networkedPlayer, steamID);
					if (_state != null)
					{
						_state.MyPlayer = val;
					}
				}
			}
			catch (Exception value)
			{
				ModLogger.Error($"[LocalPlayerManager] Error in AddNetworkedPlayerComponent: {value}");
			}
		}

		public void UpdatePlayerHp(int newHp)
		{
			if (_state != null)
			{
				_state.UpdateHp(newHp);
			}
		}

		public void UpdatePlayerMaxHp(int newMaxHp)
		{
			if (_state != null)
			{
				_state.UpdateMaxHp(newMaxHp);
			}
		}

		public void UpdatePlayerShield(float newShield)
		{
			if (_state != null)
			{
				_state.UpdateShield(newShield);
			}
		}

		public void UpdatePlayerMaxShield(float newMaxShield)
		{
			if (_state != null)
			{
				_state.UpdateMaxShield(newMaxShield);
			}
		}

		public void UpdatePlayerLevel(int newLevel)
		{
			if (_state != null)
			{
				_state.UpdateLevel(newLevel);
			}
		}

		public void UpdatePlayerXp(int newXp)
		{
			if (_state != null)
			{
				_state.UpdateXp(newXp);
			}
		}

		public void UpdatePlayerDeath(bool isDead)
		{
			if (_state != null)
			{
				_state.UpdateDeath(isDead);
				BroadcastPlayerStateChange(forceImmediate: true);
			}
		}

		public CSteamID GetLocalSteamId()
		{
			if (_state == null)
			{
				return CSteamID.Nil;
			}
			return new CSteamID(_state.SteamUserId);
		}

		public void SetAliveState()
		{
			UpdatePlayerDeath(isDead: false);
		}

		public PlayerInventory GetPlayerInventory()
		{
			if ((Object)(object)_state?.MyPlayer == (Object)null)
			{
				return null;
			}
			return _state.MyPlayer.inventory;
		}

		public void BroadcastPlayerStateChange(bool forceImmediate = false)
		{
			if (_state == null || (Object)(object)_state.Player == (Object)null || !_state.ShouldBroadcastState(Time.unscaledTime, forceImmediate))
			{
				return;
			}
			PlayerInventory playerInventory = GetPlayerInventory();
			if (playerInventory != null)
			{
				PlayerStateMessage tMsg = new PlayerStateMessage
				{
					SteamUserId = ((SteamNetworkManager.Mode == SteamNetworkMode.Client) ? _state.SteamUserId : 0),
					Hp = Math.Max(0, playerInventory.playerHealth.hp),
					MaxHp = Math.Max(0, playerInventory.playerHealth.maxHp),
					Shield = Math.Max(0f, playerInventory.playerHealth.shield),
					MaxShield = Math.Max(0f, playerInventory.playerHealth.maxShield),
					IsDead = (playerInventory.playerHealth.hp <= 0)
				};
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance?.SendMessage(tMsg);
				}
				_state.MarkStateBroadcasted(Time.unscaledTime);
			}
		}

		public void SendAttackStarted(WeaponBase weapon, Vector3 spawnPosition, Quaternion spawnRotation)
		{
			//IL_005c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0066: Expected I4, but got Unknown
			//IL_007c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0083: Unknown result type (might be due to invalid IL or missing references)
			if (_state != null && SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				uint nextAttackId = _state.GetNextAttackId();
				int attackQuantity = WeaponUtility.GetAttackQuantity(weapon);
				float burstInterval = WeaponUtility.GetBurstInterval(weapon);
				float projectileSize = GetProjectileSize(weapon);
				WeaponAttackStartedMessage tMsg = new WeaponAttackStartedMessage
				{
					SteamUserId = ((SteamNetworkManager.Mode == SteamNetworkMode.Client) ? _state.SteamUserId : 0),
					WeaponType = (int)weapon.weaponData.eWeapon,
					ProjectileCount = attackQuantity,
					BurstInterval = burstInterval,
					ProjectileSize = projectileSize,
					SpawnPosition = spawnPosition,
					SpawnRotation = spawnRotation,
					AttackId = nextAttackId
				};
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance?.SendMessage(tMsg);
				}
			}
		}

		public void SendProjectileSpawned(uint attackId, int projectileIndex, Vector3 position, Quaternion rotation)
		{
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			//IL_002c: Unknown result type (might be due to invalid IL or missing references)
			if (_state != null && SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				WeaponProjectileSpawnedMessage tMsg = new WeaponProjectileSpawnedMessage
				{
					AttackId = attackId,
					ProjectileIndex = projectileIndex,
					Position = position,
					Rotation = rotation
				};
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance?.SendMessage(tMsg);
				}
			}
		}

		public void SendProjectileHit(uint attackId, int projectileIndex, Vector3 hitPosition, Vector3 hitNormal, uint targetId, float damage)
		{
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			//IL_002c: Unknown result type (might be due to invalid IL or missing references)
			if (_state != null && SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				WeaponProjectileHitMessage tMsg = new WeaponProjectileHitMessage
				{
					AttackId = attackId,
					ProjectileIndex = projectileIndex,
					HitPosition = hitPosition,
					HitNormal = hitNormal,
					TargetId = targetId,
					Damage = damage
				};
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance?.SendMessage(tMsg);
				}
			}
		}

		private float GetProjectileSize(WeaponBase weapon)
		{
			float num = 1f;
			if (((weapon != null) ? weapon.weaponStats : null) != null && weapon.weaponStats.ContainsKey((EStat)9))
			{
				num = weapon.weaponStats[(EStat)9];
			}
			return num * 1f - 1f + 1f;
		}

		public void AnalyzeMinimapSetup()
		{
			MinimapCamera val = Object.FindObjectOfType<MinimapCamera>();
			if ((Object)(object)val == (Object)null)
			{
				return;
			}
			Camera component = ((Component)val).GetComponent<Camera>();
			if ((Object)(object)component != (Object)null)
			{
				for (int i = 0; i < 32; i++)
				{
					_ = component.cullingMask & (1 << i);
				}
			}
			_ = (Object)(object)Object.FindObjectOfType<MinimapPlayerIcon>() != (Object)null;
			foreach (InteractableShrineChallenge item in Object.FindObjectsOfType<InteractableShrineChallenge>())
			{
				if ((Object)(object)item.minimapIcon != (Object)null)
				{
					_ = item.minimapIcon.transform.parent;
				}
			}
			object obj = ((object)val).GetType().GetField("arrowPrefab", BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(val);
			if (obj != null)
			{
				_ = obj is Transform;
			}
		}
	}
	public struct PlayerState
	{
		public int CurrentHp;

		public int MaxHp;

		public float Shield;

		public float MaxShield;

		public int Level;

		public int Xp;

		public bool IsDead;
	}
	public class RemotePlayerManager : IDisposable
	{
		public struct PlayerTarget
		{
			public Transform Transform;

			public Rigidbody Rigidbody;
		}

		private class RemotePlayerStateManager : IDisposable
		{
			private readonly Dictionary<CSteamID, NetworkedPlayer> _remotePlayers = new Dictionary<CSteamID, NetworkedPlayer>();

			private MinimapCamera _minimapCamera;

			private bool _disposed;

			public int PlayerCount => _remotePlayers.Count;

			public void CreatePlayer(CSteamID steamId, ECharacter character, ESkinType skinType)
			{
				//IL_0034: Unknown result type (might be due to invalid IL or missing references)
				//IL_0045: Unknown result type (might be due to invalid IL or missing references)
				//IL_0055: Unknown result type (might be due to invalid IL or missing references)
				//IL_007a: Unknown result type (might be due to invalid IL or missing references)
				//IL_007b: Unknown result type (might be due to invalid IL or missing references)
				if (!_remotePlayers.ContainsKey(steamId))
				{
					NetworkedPlayer networkedPlayer = new GameObject($"RemotePlayer_{steamId}").AddComponent<NetworkedPlayer>();
					((Component)networkedPlayer).transform.position = Vector3.zero;
					((Component)networkedPlayer).transform.rotation = Quaternion.identity;
					((Component)networkedPlayer).gameObject.SetActive(true);
					networkedPlayer.Initialize(steamId.m_SteamID, isLocal: false, isHost: false);
					networkedPlayer.SetupVisuals(character, skinType);
					_remotePlayers[steamId] = networkedPlayer;
				}
			}

			public void RemovePlayer(CSteamID steamId)
			{
				if (_remotePlayers.TryGetValue(steamId, out var value))
				{
					if (Object.op_Implicit((Object)(object)value) && Object.op_Implicit((Object)(object)((Component)value).gameObject))
					{
						RemoveMinimapArrow(value);
						Object.Destroy((Object)(object)((Component)value).gameObject);
					}
					_remotePlayers.Remove(steamId);
				}
			}

			public NetworkedPlayer GetPlayer(CSteamID steamId)
			{
				_remotePlayers.TryGetValue(steamId, out var value);
				return value;
			}

			public IEnumerable<NetworkedPlayer> GetAllPlayers()
			{
				return _remotePlayers.Values.Where((NetworkedPlayer p) => (Object)(object)p != (Object)null);
			}

			public void UpdatePlayerState(CSteamID steamId, PlayerState state)
			{
				if (_remotePlayers.TryGetValue(steamId, out var value) && Object.op_Implicit((Object)(object)value))
				{
					value.State = state;
				}
			}

			public bool AreAllPlayersDead()
			{
				if (_remotePlayers.Count == 0)
				{
					return true;
				}
				foreach (NetworkedPlayer value in _remotePlayers.Values)
				{
					if (Object.op_Implicit((Object)(object)value) && !value.State.IsDead)
					{
						return false;
					}
				}
				return true;
			}

			public void FillPlayerTargets(List<PlayerTarget> dst)
			{
				foreach (NetworkedPlayer value in _remotePlayers.Values)
				{
					if (!((Object)(object)value == (Object)null) && !((Object)(object)((Component)value).gameObject == (Object)null) && !value.State.IsDead)
					{
						dst.Add(new PlayerTarget
						{
							Transform = ((Component)value).transform,
							Rigidbody = value.CachedRigidbody
						});
					}
				}
			}

			private MinimapCamera GetMinimapCamera()
			{
				if (!Object.op_Implicit((Object)(object)_minimapCamera))
				{
					_minimapCamera = Object.FindObjectOfType<MinimapCamera>();
				}
				return _minimapCamera;
			}

			public void AddMinimapIcons()
			{
				if (!Object.op_Implicit((Object)(object)GetMinimapCamera()))
				{
					return;
				}
				int num = 0;
				foreach (NetworkedPlayer value2 in _remotePlayers.Values)
				{
					if (!((Object)(object)value2 == (Object)null) && !((Object)(object)((Component)value2).gameObject == (Object)null))
					{
						try
						{
							AddMinimapIcon(value2);
							num++;
						}
						catch (Exception value)
						{
							ModLogger.Error($"[RemotePlayerManager] Failed to add minimap icon: {value}");
						}
					}
				}
			}

			private void AddMinimapIcon(NetworkedPlayer player)
			{
				GameObject gameObject = ((Component)((Component)GameManager.Instance.player.minimapCamera).GetComponent<MinimapCamera>().playerIcon).gameObject;
				if (!((Object)(object)gameObject == (Object)null))
				{
					Object.Instantiate<GameObject>(gameObject, ((Component)player).transform);
				}
			}

			private void RemoveMinimapArrow(NetworkedPlayer player)
			{
				MinimapCamera minimapCamera = GetMinimapCamera();
				if (!Object.op_Implicit((Object)(object)minimapCamera))
				{
					return;
				}
				try
				{
					minimapCamera.RemoveArrow(((Component)player).transform);
				}
				catch (Exception value)
				{
					ModLogger.Error($"[RemotePlayerManager] Failed to remove minimap arrow: {value}");
				}
			}

			public void Dispose()
			{
				if (_disposed)
				{
					return;
				}
				MinimapCamera minimapCamera = GetMinimapCamera();
				foreach (NetworkedPlayer value2 in _remotePlayers.Values)
				{
					if ((Object)(object)value2 == (Object)null || (Object)(object)((Component)value2).gameObject == (Object)null)
					{
						continue;
					}
					if (Object.op_Implicit((Object)(object)minimapCamera))
					{
						try
						{
							minimapCamera.RemoveArrow(((Component)value2).transform);
						}
						catch (Exception value)
						{
							ModLogger.Error($"[RemotePlayerManager] Failed to remove minimap arrow: {value}");
						}
					}
					Object.Destroy((Object)(object)((Component)value2).gameObject);
				}
				_remotePlayers.Clear();
				_minimapCamera = null;
				_disposed = true;
			}
		}

		private RemotePlayerStateManager _state;

		private readonly Color FRIEND_COLOR = new Color(0.2f, 0.8f, 1f, 1f);

		private readonly Queue<ulong> _projectileSpawnQueue = new Queue<ulong>();

		public bool IsInitialized => _state != null;

		public int PlayerCount => _state?.PlayerCount ?? 0;

		public void PushProjectileSpawnContext(ulong steamId)
		{
			_projectileSpawnQueue.Enqueue(steamId);
		}

		public bool TryGetProjectileSpawnContext(out ulong steamId)
		{
			if (_projectileSpawnQueue.Count > 0)
			{
				steamId = _projectileSpawnQueue.Dequeue();
				return true;
			}
			steamId = 0uL;
			return false;
		}

		public void Initialize()
		{
			if (_state != null)
			{
				Shutdown();
			}
			_state = new RemotePlayerStateManager();
		}

		public void Shutdown()
		{
			if (_state != null)
			{
				_state.Dispose();
				_state = null;
			}
		}

		public void ClearState()
		{
			Shutdown();
		}

		public void Dispose()
		{
			Shutdown();
		}

		public void OnGameStarted(CSteamID steamId, ECharacter character, ESkinType skinType)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_001b: Unknown result type (might be due to invalid IL or missing references)
			if (_state == null)
			{
				ModLogger.Error("[RemotePlayerManager] Cannot create player - not initialized! Call Initialize() first.");
			}
			else
			{
				_state.CreatePlayer(steamId, character, skinType);
			}
		}

		public void OnPlayerLeft(CSteamID steamId)
		{
			if (_state != null)
			{
				_state.RemovePlayer(steamId);
			}
		}

		public NetworkedPlayer GetPlayer(CSteamID steamId)
		{
			if (_state == null)
			{
				return null;
			}
			return _state.GetPlayer(steamId);
		}

		public IEnumerable<NetworkedPlayer> GetAllPlayers()
		{
			if (_state == null)
			{
				return Enumerable.Empty<NetworkedPlayer>();
			}
			return _state.GetAllPlayers();
		}

		public void UpdatePlayerState(CSteamID steamId, PlayerState state)
		{
			if (_state != null)
			{
				_state.UpdatePlayerState(steamId, state);
			}
		}

		public bool AreAllRemotePlayersDead()
		{
			if (_state == null)
			{
				return true;
			}
			return _state.AreAllPlayersDead();
		}

		public void FillAllPlayerTargets(List<PlayerTarget> dst)
		{
			if (dst == null)
			{
				throw new ArgumentNullException("dst");
			}
			dst.Clear();
			MatchContext current = MatchContext.Current;
			if (current != null && current.LocalPlayer.IsInitialized && (Object)(object)MatchContext.Current.LocalPlayer.LocalPlayer != (Object)null && !MatchContext.Current.LocalPlayer.LocalPlayerState.IsDead)
			{
				Rigidbody component = ((Component)MatchContext.Current.LocalPlayer.LocalPlayer).GetComponent<Rigidbody>();
				if (Object.op_Implicit((Object)(object)component))
				{
					dst.Add(new PlayerTarget
					{
						Transform = ((Component)MatchContext.Current.LocalPlayer.LocalPlayer).transform,
						Rigidbody = component
					});
				}
			}
			if (_state != null)
			{
				_state.FillPlayerTargets(dst);
			}
		}

		public void AddMinimapIcons()
		{
			if (_state != null)
			{
				_state.AddMinimapIcons();
			}
		}
	}
	public class RemotePlayerTransformContext : IDisposable
	{
		private readonly Queue<ulong> _transformContextQueue = new Queue<ulong>();

		public void PushContext(ulong playerId)
		{
			_transformContextQueue.Enqueue(playerId);
		}

		public void PopContext()
		{
			if (_transformContextQueue.Count > 0)
			{
				_transformContextQueue.Dequeue();
			}
		}

		public bool HasActiveContext()
		{
			return _transformContextQueue.Count > 0;
		}

		public bool TryGetCurrentContext(out ulong playerId)
		{
			playerId = 0uL;
			if (_transformContextQueue.Count > 0)
			{
				playerId = _transformContextQueue.Peek();
				return true;
			}
			return false;
		}

		public void Dispose()
		{
			_transformContextQueue.Clear();
		}
	}
}
namespace Megabonk.BonkWithFriends.Managers.World
{
	public class SpawnedObjectManager : IDisposable
	{
		private struct PendingSpawn
		{
			public int Id;

			public string PrefabName;

			public Vector3 Position;

			public Quaternion Rotation;

			public Vector3 Scale;

			public int SubType;
		}

		public bool CanSendNetworkMessages = true;

		private readonly Dictionary<int, GameObject> _idToObject = new Dictionary<int, GameObject>(256);

		private readonly Dictionary<GameObject, int> _objectToId = new Dictionary<GameObject, int>(256);

		private int _nextObjectId;

		private readonly List<PendingSpawn> _pendingSpawns = new List<PendingSpawn>(128);

		private bool _prefabsRegistered;

		private readonly List<SpawnedObjectBatchMessage> _deferredBatches = new List<SpawnedObjectBatchMessage>(4);

		private readonly Dictionary<string, GameObject> _prefabRegistry = new Dictionary<string, GameObject>(128);

		private SpawnInteractables _spawnerCache;

		private RandomObjectPlacer _randomPlacerCache;

		public T GetSpecific<T>() where T : MonoBehaviour
		{
			foreach (KeyValuePair<int, GameObject> item in _idToObject)
			{
				if (!((Object)(object)item.Value == (Object)null))
				{
					T component = item.Value.GetComponent<T>();
					if ((Object)(object)component != (Object)null)
					{
						return component;
					}
				}
			}
			return default(T);
		}

		public bool ArePrefabsRegistered()
		{
			return _prefabsRegistered;
		}

		public void OnPrefabRegistrationComplete()
		{
			foreach (SpawnedObjectBatchMessage deferredBatch in _deferredBatches)
			{
				ProcessSpawnedObjectBatch(deferredBatch);
			}
			_deferredBatches.Clear();
			_prefabsRegistered = true;
		}

		public void AddPrefab(GameObject prefab)
		{
			if (!((Object)(object)prefab == (Object)null))
			{
				_prefabRegistry.TryAdd(((Object)prefab).name, prefab);
			}
		}

		private GameObject GetPrefabFromRegistry(string prefabName)
		{
			if (string.IsNullOrEmpty(prefabName))
			{
				return null;
			}
			if (_prefabRegistry.TryGetValue(prefabName, out var value))
			{
				return value;
			}
			return null;
		}

		private void ClearPrefabRegistry()
		{
			_prefabRegistry.Clear();
		}

		private SpawnInteractables GetSpawner()
		{
			if ((Object)(object)_spawnerCache == (Object)null)
			{
				_spawnerCache = Object.FindObjectOfType<SpawnInteractables>();
			}
			return _spawnerCache;
		}

		private RandomObjectPlacer GetRandomPlacer()
		{
			if ((Object)(object)_randomPlacerCache == (Object)null)
			{
				_randomPlacerCache = Object.FindObjectOfType<RandomObjectPlacer>();
			}
			return _randomPlacerCache;
		}

		public void RegisterHostObject(GameObject go, string prefabName, Vector3 position, Quaternion rotation, int subType = 0)
		{
			//IL_0064: Unknown result type (might be due to invalid IL or missing references)
			//IL_0065: Unknown result type (might be due to invalid IL or missing references)
			//IL_006c: Unknown result type (might be due to invalid IL or missing references)
			//IL_006e: Unknown result type (might be due to invalid IL or missing references)
			//IL_007b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0080: Unknown result type (might be due to invalid IL or missing references)
			if (Object.op_Implicit((Object)(object)go) && !_objectToId.ContainsKey(go))
			{
				int num = _nextObjectId++;
				_idToObject[num] = go;
				_objectToId[go] = num;
				_pendingSpawns.Add(new PendingSpawn
				{
					Id = num,
					PrefabName = prefabName,
					Position = position,
					Rotation = rotation,
					Scale = go.transform.localScale,
					SubType = subType
				});
			}
		}

		public void RegisterClientObject(int id, GameObject go)
		{
			if (Object.op_Implicit((Object)(object)go) && !_objectToId.ContainsKey(go))
			{
				_idToObject[id] = go;
				_objectToId[go] = id;
				if (id >= _nextObjectId)
				{
					_nextObjectId = id + 1;
				}
			}
		}

		public GameObject GetObject(int id)
		{
			_idToObject.TryGetValue(id, out var value);
			return value;
		}

		public int GetObjectId(GameObject go)
		{
			if (!Object.op_Implicit((Object)(object)go))
			{
				return -1;
			}
			if (!_objectToId.TryGetValue(go, out var value))
			{
				return -1;
			}
			return value;
		}

		public bool TryGetObjectId(GameObject go, out int id)
		{
			id = GetObjectId(go);
			return id != -1;
		}

		private void UnregisterObject(int id)
		{
			if (_idToObject.TryGetValue(id, out var value))
			{
				_idToObject.Remove(id);
				if (Object.op_Implicit((Object)(object)value))
				{
					_objectToId.Remove(value);
				}
			}
		}

		public void BroadcastPendingSpawns()
		{
			//IL_006b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0070: Unknown result type (might be due to invalid IL or missing references)
			//IL_0078: Unknown result type (might be due to invalid IL or missing references)
			//IL_007d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0085: Unknown result type (might be due to invalid IL or missing references)
			//IL_008a: Unknown result type (might be due to invalid IL or missing references)
			if (_pendingSpawns.Count == 0)
			{
				return;
			}
			SpawnedObjectBatchMessage spawnedObjectBatchMessage = new SpawnedObjectBatchMessage
			{
				Spawns = new List<SpawnedObjectData>(_pendingSpawns.Count)
			};
			foreach (PendingSpawn pendingSpawn in _pendingSpawns)
			{
				spawnedObjectBatchMessage.Spawns.Add(new SpawnedObjectData
				{
					Id = pendingSpawn.Id,
					PrefabName = pendingSpawn.PrefabName,
					Position = pendingSpawn.Position,
					Rotation = pendingSpawn.Rotation,
					Scale = pendingSpawn.Scale,
					SubType = pendingSpawn.SubType
				});
			}
			SteamNetworkServer.Instance?.BroadcastMessage(spawnedObjectBatchMessage);
		}

		internal void HandleSpawnedObjectBatch(SpawnedObjectBatchMessage msg)
		{
			if (msg?.Spawns != null)
			{
				ProcessSpawnedObjectBatch(msg);
			}
		}

		private void ProcessSpawnedObjectBatch(SpawnedObjectBatchMessage msg)
		{
			foreach (SpawnedObjectData spawn in msg.Spawns)
			{
				SpawnClientObject(spawn);
			}
		}

		private void SpawnClientObject(SpawnedObjectData data)
		{
			//IL_0038: Unknown result type (might be due to invalid IL or missing references)
			//IL_0049: Unknown result type (might be due to invalid IL or missing references)
			//IL_005a: Unknown result type (might be due to invalid IL or missing references)
			GameObject prefabByName = GetPrefabByName(data.PrefabName);
			if (Object.op_Implicit((Object)(object)prefabByName))
			{
				GameObject val = Object.Instantiate<GameObject>(prefabByName);
				if (Object.op_Implicit((Object)(object)val))
				{
					val.transform.SetParent((Transform)null);
					val.transform.position = data.Position;
					val.transform.rotation = data.Rotation;
					val.transform.localScale = data.Scale;
					ApplySubTypeData(val, data.SubType);
					RegisterClientObject(data.Id, val);
				}
			}
		}

		private void ApplySubTypeData(GameObject instance, int subTypeValue)
		{
			//IL_0006: Unknown result type (might be due to invalid IL or missing references)
			//IL_0017: Unknown result type (might be due to invalid IL or missing references)
			//IL_002e: Unknown result type (might be due to invalid IL or missing references)
			if (subTypeValue <= 0)
			{
				return;
			}
			EItemRarity rarity = (EItemRarity)subTypeValue;
			InteractableShadyGuy componentInChildren = instance.GetComponentInChildren<InteractableShadyGuy>();
			if (Object.op_Implicit((Object)(object)componentInChildren))
			{
				componentInChildren.rarity = rarity;
				return;
			}
			InteractableMicrowave componentInChildren2 = instance.GetComponentInChildren<InteractableMicrowave>();
			if (Object.op_Implicit((Object)(object)componentInChildren2))
			{
				componentInChildren2.rarity = rarity;
			}
		}

		private GameObject GetPrefabByName(string prefabName)
		{
			string text = prefabName.Trim();
			if (text.EndsWith("(Clone)"))
			{
				text = text.Substring(0, text.Length - 7);
			}
			GameObject prefabFromRegistry = GetPrefabFromRegistry(text);
			if ((Object)(object)prefabFromRegistry != (Object)null)
			{
				return prefabFromRegistry;
			}
			try
			{
				SpawnInteractables spawner = GetSpawner();
				MapData currentMap = MapController.currentMap;
				if (Object.op_Implicit((Object)(object)spawner))
				{
					if (Object.op_Implicit((Object)(object)spawner.chest) && prefabName.StartsWith(((Object)spawner.chest).name))
					{
						return spawner.chest;
					}
					if (Object.op_Implicit((Object)(object)spawner.chestFree) && prefabName.StartsWith(((Object)spawner.chestFree).name))
					{
						return spawner.chestFree;
					}
				}
				if (((currentMap != null) ? currentMap.shrines : null) != null)
				{
					foreach (GameObject item in (Il2CppArrayBase<GameObject>)(object)currentMap.shrines)
					{
						if (Object.op_Implicit((Object)(object)item) && prefabName.StartsWith(((Object)item).name))
						{
							return item;
						}
					}
				}
				EffectManager instance = EffectManager.Instance;
				if (Object.op_Implicit((Object)(object)((instance != null) ? instance.bananaQuest : null)) && prefabName.StartsWith(((Object)EffectManager.Instance.bananaQuest).name))
				{
					return EffectManager.Instance.bananaQuest;
				}
				RandomObjectPlacer randomPlacer = GetRandomPlacer();
				if (((randomPlacer != null) ? randomPlacer.randomObjects : null) != null)
				{
					foreach (RandomMapObject item2 in (Il2CppArrayBase<RandomMapObject>)(object)randomPlacer.randomObjects)
					{
						if (((item2 != null) ? item2.prefabs : null) == null)
						{
							continue;
						}
						foreach (GameObject item3 in (Il2CppArrayBase<GameObject>)(object)item2.prefabs)
						{
							if (Object.op_Implicit((Object)(object)item3) && prefabName.StartsWith(((Object)item3).name))
							{
								return item3;
							}
						}
					}
				}
				return null;
			}
			catch (Exception value)
			{
				ModLogger.Error($"[SpawnedObjectManager] Error finding prefab '{prefabName}': {value}");
				return null;
			}
		}

		public void BroadcastObjectUsed(GameObject objectGO, ulong playerSteamId)
		{
			int objectId = GetObjectId(objectGO);
			if (objectId != -1)
			{
				InteractableUsedMessage tMsg = new InteractableUsedMessage
				{
					PlayerSteamId = playerSteamId,
					ObjectId = objectId
				};
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance?.SendMessage(tMsg);
				}
			}
		}

		internal void HandleObjectUsed(InteractableUsedMessage msg)
		{
			GameObject val = GetObject(msg.ObjectId);
			if (!Object.op_Implicit((Object)(object)val))
			{
				return;
			}
			CanSendNetworkMessages = false;
			try
			{
				if (Object.op_Implicit((Object)(object)val.GetComponent<InteractableChest>()))
				{
					UnregisterObject(msg.ObjectId);
					Object.Destroy((Object)(object)val);
					return;
				}
				InteractableShrineCursed component = val.GetComponent<InteractableShrineCursed>();
				if ((Object)(object)component != (Object)null)
				{
					((BaseInteractable)component).Interact();
					return;
				}
				InteractableShrineGreed component2 = val.GetComponent<InteractableShrineGreed>();
				if ((Object)(object)component2 != (Object)null)
				{
					((BaseInteractable)component2).Interact();
					return;
				}
				InteractableShrineChallenge component3 = val.GetComponent<InteractableShrineChallenge>();
				if ((Object)(object)component3 != (Object)null)
				{
					((BaseInteractable)component3).Interact();
					return;
				}
				InteractableShrineMagnet component4 = val.GetComponent<InteractableShrineMagnet>();
				if ((Object)(object)component4 != (Object)null)
				{
					((BaseInteractable)component4).Interact();
					return;
				}
				InteractableBossSpawner component5 = val.GetComponent<InteractableBossSpawner>();
				if ((Object)(object)component5 != (Object)null)
				{
					((BaseInteractable)component5).Interact();
					return;
				}
				InteractableBossSpawnerFinal component6 = val.GetComponent<InteractableBossSpawnerFinal>();
				if ((Object)(object)component6 != (Object)null)
				{
					((BaseInteractable)component6).Interact();
					return;
				}
				InteractableCharacterFight componentInChildren = val.GetComponentInChildren<InteractableCharacterFight>();
				if ((Object)(object)componentInChildren != (Object)null)
				{
					componentInChildren.chargeFx.SetActive(true);
					val.SetActive(false);
					return;
				}
				InteractableTumbleWeed component7 = val.GetComponent<InteractableTumbleWeed>();
				if ((Object)(object)component7 != (Object)null)
				{
					((BaseInteractable)component7).Interact();
					return;
				}
				InteractablePot component8 = val.GetComponent<InteractablePot>();
				if ((Object)(object)component8 != (Object)null)
				{
					((BaseInteractable)component8).Interact();
					return;
				}
				InteractableBoombox componentInChildren2 = val.GetComponentInChildren<InteractableBoombox>();
				if ((Object)(object)componentInChildren2 != (Object)null)
				{
					((BaseInteractable)componentInChildren2).Interact();
					return;
				}
				InteractableDesertGrave componentInChildren3 = val.GetComponentInChildren<InteractableDesertGrave>();
				if ((Object)(object)componentInChildren3 != (Object)null)
				{
					((BaseInteractable)componentInChildren3).Interact();
					val.SetActive(false);
					return;
				}
				InteractableSkeletonKingStatue componentInChildren4 = val.GetComponentInChildren<InteractableSkeletonKingStatue>();
				if ((Object)(object)componentInChildren4 != (Object)null)
				{
					((BaseInteractable)componentInChildren4).Interact();
					val.SetActive(false);
					return;
				}
				InteractableCryptLeave componentInChildren5 = val.GetComponentInChildren<InteractableCryptLeave>();
				if ((Object)(object)componentInChildren5 != (Object)null)
				{
					((BaseInteractable)componentInChildren5).Interact();
					return;
				}
				InteractableCoffin componentInChildren6 = val.GetComponentInChildren<InteractableCoffin>();
				if ((Object)(object)componentInChildren6 != (Object)null)
				{
					((BaseInteractable)componentInChildren6).Interact();
					return;
				}
				InteractableCrypt componentInChildren7 = val.GetComponentInChildren<InteractableCrypt>();
				if ((Object)(object)componentInChildren7 != (Object)null)
				{
					((BaseInteractable)componentInChildren7).Interact();
					return;
				}
				InteractableGhostBossLeave componentInChildren8 = val.GetComponentInChildren<InteractableGhostBossLeave>();
				if ((Object)(object)componentInChildren8 != (Object)null)
				{
					((BaseInteractable)componentInChildren8).Interact();
					return;
				}
				InteractableGift componentInChildren9 = val.GetComponentInChildren<InteractableGift>();
				if ((Object)(object)componentInChildren9 != (Object)null)
				{
					((BaseInteractable)componentInChildren9).Interact();
					return;
				}
				InteractableGravestone componentInChildren10 = val.GetComponentInChildren<InteractableGravestone>();
				if ((Object)(object)componentInChildren10 != (Object)null)
				{
					((BaseInteractable)componentInChildren10).Interact();
				}
			}
			finally
			{
				CanSendNetworkMessages = true;
			}
		}

		public void Dispose()
		{
			_idToObject.Clear();
			_objectToId.Clear();
			_pendingSpawns.Clear();
			_deferredBatches.Clear();
			_prefabRegistry.Clear();
			_prefabsRegistered = false;
			_nextObjectId = 0;
			_spawnerCache = null;
			_randomPlacerCache = null;
			CanSendNetworkMessages = true;
		}
	}
	[Serializable]
	public struct SpawnedObjectData
	{
		public int Id;

		public string PrefabName;

		public Vector3 Position;

		public Quaternion Rotation;

		public Vector3 Scale;

		public int SubType;
	}
	public static class ChargeShrineState
	{
		private static readonly Dictionary<int, HashSet<ulong>> _shrineChargers = new Dictionary<int, HashSet<ulong>>(16);

		public static bool AddCharger(int shrineObjectId, ulong playerSteamId)
		{
			if (!_shrineChargers.TryGetValue(shrineObjectId, out var value))
			{
				value = new HashSet<ulong>();
				_shrineChargers[shrineObjectId] = value;
			}
			bool result = value.Count == 0;
			value.Add(playerSteamId);
			return result;
		}

		public static bool RemoveCharger(int shrineObjectId, ulong playerSteamId)
		{
			if (!_shrineChargers.TryGetValue(shrineObjectId, out var value))
			{
				return true;
			}
			value.Remove(playerSteamId);
			return value.Count == 0;
		}

		public static bool HasChargers(int shrineObjectId)
		{
			if (_shrineChargers.TryGetValue(shrineObjectId, out var value))
			{
				return value.Count > 0;
			}
			return false;
		}

		public static void ClearState()
		{
			_shrineChargers.Clear();
		}
	}
}
namespace Megabonk.BonkWithFriends.Managers.Items
{
	public class PickupSpawnManager : IDisposable
	{
		private struct PendingPickupSpawn
		{
			public int PickupId;

			public int EPickup;

			public Vector3 Position;

			public int Value;
		}

		public bool IsSpawningFromNetwork;

		public bool IsProcessingNetworkDespawn;

		private Dictionary<int, Pickup> _pickupRegistry = new Dictionary<int, Pickup>();

		private int _nextPickupId;

		private readonly Dictionary<int, ulong> _pickupOwners = new Dictionary<int, ulong>();

		public bool IsProcessingRemoteCollection;

		private readonly Queue<PendingPickupSpawn> _pendingSpawns = new Queue<PendingPickupSpawn>();

		private readonly Queue<int> _pendingDespawns = new Queue<int>();

		public void SetPickupOwner(int pickupId, ulong steamId)
		{
			_pickupOwners[pickupId] = steamId;
		}

		public bool IsOwnedByLocal(int pickupId)
		{
			if (!_pickupOwners.TryGetValue(pickupId, out var value))
			{
				return true;
			}
			return value == SteamUser.GetSteamID().m_SteamID;
		}

		public int RegisterPickup(Pickup pickup)
		{
			if (!Object.op_Implicit((Object)(object)pickup))
			{
				return -1;
			}
			int num = _nextPickupId++;
			_pickupRegistry[num] = pickup;
			return num;
		}

		public void RegisterPickupWithId(int pickupId, Pickup pickup)
		{
			if (Object.op_Implicit((Object)(object)pickup))
			{
				_pickupRegistry[pickupId] = pickup;
				if (pickupId >= _nextPickupId)
				{
					_nextPickupId = pickupId + 1;
				}
			}
		}

		public Pickup GetPickup(int pickupId)
		{
			_pickupRegistry.TryGetValue(pickupId, out var value);
			return value;
		}

		public int GetPickupId(Pickup pickup)
		{
			foreach (KeyValuePair<int, Pickup> item in _pickupRegistry)
			{
				if ((Object)(object)item.Value == (Object)(object)pickup)
				{
					return item.Key;
				}
			}
			return -1;
		}

		public void GetAllXpPickups(List<Pickup> buffer)
		{
			//IL_002b: Unknown result type (might be due to invalid IL or missing references)
			buffer.Clear();
			foreach (Pickup value in _pickupRegistry.Values)
			{
				if ((Object)(object)value != (Object)null && (int)value.ePickup == 0 && !value.pickedUp)
				{
					buffer.Add(value);
				}
			}
		}

		public void UnregisterPickup(int id)
		{
			//IL_0011: Unknown result type (might be due to invalid IL or missing references)
			if (!_pickupRegistry.TryGetValue(id, out var value))
			{
				return;
			}
			if ((int)value.ePickup == 0)
			{
				PickupManager instance = PickupManager.Instance;
				if (((instance != null) ? instance.xpList : null) != null)
				{
					PickupManager.Instance.xpList.RemovePickup(value);
				}
			}
			_pickupRegistry.Remove(id);
			_pickupOwners.Remove(id);
		}

		public void BroadcastPickupSpawned(Pickup pickup, int ePickup)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_001f: Unknown result type (might be due to invalid IL or missing references)
			//IL_004e: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server || !Object.op_Implicit((Object)(object)pickup))
			{
				return;
			}
			try
			{
				Vector3 position = ((Component)pickup).transform.position;
				int value = pickup.GetValue();
				int pickupId = RegisterPickup(pickup);
				SteamNetworkServer.Instance?.BroadcastMessage(new PickupSpawnedMessage
				{
					PickupId = pickupId,
					EPickup = ePickup,
					Position = position,
					Value = value
				});
			}
			catch (Exception)
			{
			}
		}

		public void ProcessPickupCollection(int pickupId)
		{
			if (!_pickupRegistry.TryGetValue(pickupId, out var value))
			{
				return;
			}
			if (!Object.op_Implicit((Object)(object)value))
			{
				UnregisterPickup(pickupId);
				return;
			}
			value.pickedUp = true;
			if (Object.op_Implicit((Object)(object)PickupManager.Instance))
			{
				IsProcessingNetworkDespawn = true;
				try
				{
					PickupManager.Instance.DespawnPickup(value);
				}
				finally
				{
					IsProcessingNetworkDespawn = false;
				}
			}
			else
			{
				Object.Destroy((Object)(object)((Component)value).gameObject);
			}
			UnregisterPickup(pickupId);
		}

		internal void HandlePickupSpawn(PickupSpawnedMessage msg)
		{
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			//IL_002a: Unknown result type (might be due to invalid IL or missing references)
			try
			{
				PendingPickupSpawn item = new PendingPickupSpawn
				{
					PickupId = msg.PickupId,
					EPickup = msg.EPickup,
					Position = msg.Position,
					Value = msg.Value
				};
				_pendingSpawns.Enqueue(item);
			}
			catch (Exception)
			{
			}
		}

		public void ProcessPendingSpawns()
		{
			//IL_0045: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server || _pendingSpawns.Count == 0 || !Object.op_Implicit((Object)(object)PickupManager.Instance))
			{
				return;
			}
			PendingPickupSpawn result;
			while (_pendingSpawns.TryDequeue(out result))
			{
				try
				{
					IsSpawningFromNetwork = true;
					Pickup val = PickupManager.Instance.SpawnPickup((EPickup)result.EPickup, result.Position, result.Value, false, 0f);
					if (Object.op_Implicit((Object)(object)val))
					{
						RegisterPickupWithId(result.PickupId, val);
					}
				}
				catch (Exception)
				{
				}
				finally
				{
					IsSpawningFromNetwork = false;
				}
			}
		}

		public void ProcessPendingDespawns()
		{
			if ((Object)(object)PickupManager.Instance == (Object)null)
			{
				return;
			}
			int result;
			while (_pendingDespawns.TryDequeue(out result))
			{
				Pickup pickup = GetPickup(result);
				if ((Object)(object)pickup != (Object)null)
				{
					UnregisterPickup(result);
					pickup.pickedUp = true;
					PickupManager.Instance.DespawnPickup(pickup);
				}
			}
		}

		public void QueuePickupDespawn(int pickupId)
		{
			_pendingDespawns.Enqueue(pickupId);
		}

		public void QueueRemotePickupDespawn(int pickupId)
		{
			QueuePickupDespawn(pickupId);
		}

		public void Dispose()
		{
			_pickupRegistry.Clear();
			_pickupOwners.Clear();
			_pendingSpawns.Clear();
			_pendingDespawns.Clear();
			_nextPickupId = 0;
			IsProcessingRemoteCollection = false;
		}
	}
}
namespace Megabonk.BonkWithFriends.Managers.Enemies
{
	public sealed class EnemyInterpolatedTransform
	{
		public sealed class Config
		{
			public float InterpSpeedHorizontal = 40f;

			public float InterpSpeedVertical = 40f;

			public float MinExtrap = 0.05f;

			public float MaxExtrapMult = 1.5f;

			public float InterpolationDelay = 0.2f;

			public float TeleportDistSq = 70f;

			public float TeleportAngleDeg = 45f;

			public bool YawOnly;

			public bool EnableGrounding;

			public float RaycastUp = 1f;

			public float RaycastDown = 2.5f;

			public float FootOffset = 0.05f;

			public float VerticalSnapMax = 0.5f;

			public int GroundMask = -1;

			public float GroundCheckInterval = 0.2f;

			public static readonly Config DefaultEnemy = new Config();
		}

		private struct Snapshot
		{
			public Vector3 Position;

			public Quaternion Rotation;

			public Vector3 Velocity;

			public float ServerTime;
		}

		private readonly Config _cfg;

		public Vector3 CurrentPosition;

		public Quaternion CurrentRotation;

		public Vector3 TargetPosition;

		public Quaternion TargetRotation;

		public Vector3 Velocity;

		public float AngularVelDegPerSec;

		public float LastServerTime;

		public uint LastSeq;

		public bool HasBaseline;

		private const int MAX_SNAPSHOTS = 32;

		private readonly Snapshot[] _snapshotBuffer = new Snapshot[32];

		private int _snapshotCount;

		private int _snapshotHead;

		private float _nextGroundCheckTime;

		private float _lastGroundY;

		public EnemyInterpolatedTransform(Config cfg = null)
		{
			_cfg = cfg ?? Config.DefaultEnemy;
		}

		public void SetTarget(float serverTime, uint seq, in Vector3 pos, in Quaternion rotIn, in Vector3 velIn, float angVelDegPerSec = 0f)
		{
			//IL_0022: Unknown result type (might be due to invalid IL or missing references)
			//IL_0027: Unknown result type (might be due to invalid IL or missing references)
			//IL_0055: Unknown result type (might be due to invalid IL or missing references)
			//IL_005a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0060: Unknown result type (might be due to invalid IL or missing references)
			//IL_0061: Unknown result type (might be due to invalid IL or missing references)
			//IL_0069: Unknown result type (might be due to invalid IL or missing references)
			//IL_006e: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a3: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a8: Unknown result type (might be due to invalid IL or missing references)
			//IL_00af: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b0: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b9: Unknown result type (might be due to invalid IL or missing references)
			//IL_00be: Unknown result type (might be due to invalid IL or missing references)
			//IL_0037: Unknown result type (might be due to invalid IL or missing references)
			//IL_003c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0042: Unknown result type (might be due to invalid IL or missing references)
			//IL_004d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0052: Unknown result type (might be due to invalid IL or missing references)
			//IL_00f3: Unknown result type (might be due to invalid IL or missing references)
			//IL_00f8: Unknown result type (might be due to invalid IL or missing references)
			//IL_00fe: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ff: Unknown result type (might be due to invalid IL or missing references)
			if (!HasBaseline || seq > LastSeq)
			{
				LastSeq = seq;
				LastServerTime = serverTime;
				Quaternion rotIn2 = rotIn;
				if (_cfg.YawOnly)
				{
					Vector3 eulerAngles = ((Quaternion)(ref rotIn2)).eulerAngles;
					rotIn2 = Quaternion.Euler(0f, eulerAngles.y, 0f);
				}
				TargetPosition = pos;
				TargetRotation = rotIn2;
				Velocity = velIn;
				AngularVelDegPerSec = angVelDegPerSec;
				_snapshotHead = (_snapshotHead + 1) % 32;
				_snapshotBuffer[_snapshotHead] = new Snapshot
				{
					Position = pos,
					Rotation = rotIn2,
					Velocity = velIn,
					ServerTime = serverTime
				};
				if (_snapshotCount < 32)
				{
					_snapshotCount++;
				}
				if (!HasBaseline)
				{
					CurrentPosition = pos;
					CurrentRotation = rotIn2;
					HasBaseline = true;
					_lastGroundY = pos.y;
					Teleport(in pos, in rotIn2);
				}
			}
		}

		public void Update(Transform t)
		{
			//IL_001b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0021: Unknown result type (might be due to invalid IL or missing references)
			//IL_022f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0235: Unknown result type (might be due to invalid IL or missing references)
			//IL_023c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0241: Unknown result type (might be due to invalid IL or missing references)
			//IL_0246: Unknown result type (might be due to invalid IL or missing references)
			//IL_024d: Unknown result type (might be due to invalid IL or missing references)
			//IL_026f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0274: Unknown result type (might be due to invalid IL or missing references)
			//IL_0276: Unknown result type (might be due to invalid IL or missing references)
			//IL_027b: Unknown result type (might be due to invalid IL or missing references)
			//IL_027c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0281: Unknown result type (might be due to invalid IL or missing references)
			//IL_029b: Unknown result type (might be due to invalid IL or missing references)
			//IL_02a0: Unknown result type (might be due to invalid IL or missing references)
			//IL_014b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0152: Unknown result type (might be due to invalid IL or missing references)
			//IL_0157: Unknown result type (might be due to invalid IL or missing references)
			//IL_015b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0162: Unknown result type (might be due to invalid IL or missing references)
			//IL_0167: Unknown result type (might be due to invalid IL or missing references)
			//IL_0182: Unknown result type (might be due to invalid IL or missing references)
			//IL_0187: Unknown result type (might be due to invalid IL or missing references)
			//IL_019a: Unknown result type (might be due to invalid IL or missing references)
			//IL_019c: Unknown result type (might be due to invalid IL or missing references)
			//IL_01a1: Unknown result type (might be due to invalid IL or missing references)
			//IL_01b9: Unknown result type (might be due to invalid IL or missing references)
			//IL_01be: Unknown result type (might be due to invalid IL or missing references)
			//IL_01c3: Unknown result type (might be due to invalid IL or missing references)
			//IL_01cd: Unknown result type (might be due to invalid IL or missing references)
			//IL_01cf: Unknown result type (might be due to invalid IL or missing references)
			//IL_01d4: Unknown result type (might be due to invalid IL or missing references)
			//IL_01d9: Unknown result type (might be due to invalid IL or missing references)
			//IL_01dc: Unknown result type (might be due to invalid IL or missing references)
			//IL_01e3: Unknown result type (might be due to invalid IL or missing references)
			//IL_01ea: Unknown result type (might be due to invalid IL or missing references)
			//IL_01ef: Unknown result type (might be due to invalid IL or missing references)
			//IL_011a: Unknown result type (might be due to invalid IL or missing references)
			//IL_011f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0122: Unknown result type (might be due to invalid IL or missing references)
			//IL_0127: Unknown result type (might be due to invalid IL or missing references)
			//IL_02c7: Unknown result type (might be due to invalid IL or missing references)
			//IL_02c8: Unknown result type (might be due to invalid IL or missing references)
			//IL_02ce: Unknown result type (might be due to invalid IL or missing references)
			//IL_02cf: Unknown result type (might be due to invalid IL or missing references)
			//IL_02d6: Unknown result type (might be due to invalid IL or missing references)
			//IL_02dc: Unknown result type (might be due to invalid IL or missing references)
			//IL_031a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0321: Unknown result type (might be due to invalid IL or missing references)
			//IL_0327: Unknown result type (might be due to invalid IL or missing references)
			//IL_034e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0352: Unknown result type (might be due to invalid IL or missing references)
			//IL_0357: Unknown result type (might be due to invalid IL or missing references)
			//IL_0380: Unknown result type (might be due to invalid IL or missing references)
			//IL_0390: Unknown result type (might be due to invalid IL or missing references)
			//IL_0399: Unknown result type (might be due to invalid IL or missing references)
			//IL_03a0: Unknown result type (might be due to invalid IL or missing references)
			//IL_03a5: Unknown result type (might be due to invalid IL or missing references)
			//IL_03ac: Unknown result type (might be due to invalid IL or missing references)
			//IL_03b1: Unknown result type (might be due to invalid IL or missing references)
			//IL_03b4: Unknown result type (might be due to invalid IL or missing references)
			//IL_03b9: Unknown result type (might be due to invalid IL or missing references)
			//IL_03c0: Unknown result type (might be due to invalid IL or missing references)
			//IL_03c6: Unknown result type (might be due to invalid IL or missing references)
			if (!Object.op_Implicit((Object)(object)t) || !HasBaseline)
			{
				return;
			}
			if (_snapshotCount == 0)
			{
				t.SetPositionAndRotation(CurrentPosition, CurrentRotation);
				return;
			}
			MatchContext current = MatchContext.Current;
			float num = ((current == null || !current.TimeSync.IsInitialized) ? LastServerTime : MatchContext.Current.TimeSync.CurrentServerTime);
			float num2 = num - _cfg.InterpolationDelay;
			bool flag = false;
			int num3 = -1;
			int num4 = -1;
			if (_snapshotCount >= 2)
			{
				for (int i = 0; i < _snapshotCount; i++)
				{
					int num5 = (_snapshotHead - i + 32) % 32;
					if (_snapshotBuffer[num5].ServerTime <= num2)
					{
						num3 = num5;
						if (i > 0)
						{
							num4 = (_snapshotHead - (i - 1) + 32) % 32;
							flag = true;
						}
						break;
					}
				}
			}
			Vector3 desiredPos;
			Quaternion val;
			if (flag)
			{
				Snapshot snapshot = _snapshotBuffer[num3];
				Snapshot snapshot2 = _snapshotBuffer[num4];
				float num6 = snapshot2.ServerTime - snapshot.ServerTime;
				if (num6 < 0.0001f)
				{
					desiredPos = snapshot.Position;
					val = snapshot.Rotation;
				}
				else
				{
					float num7 = (num2 - snapshot.ServerTime) / num6;
					float num8 = num7 * num7;
					float num9 = num8 * num7;
					Vector3 val2 = snapshot.Velocity * num6;
					Vector3 val3 = snapshot2.Velocity * num6;
					desiredPos = (2f * num9 - 3f * num8 + 1f) * snapshot.Position + (num9 - 2f * num8 + num7) * val2 + (-2f * num9 + 3f * num8) * snapshot2.Position + (num9 - num8) * val3;
					val = Quaternion.Slerp(snapshot.Rotation, snapshot2.Rotation, num7);
				}
			}
			else
			{
				float num10 = Mathf.Max(0f, num2 - LastServerTime);
				float num11 = _cfg.InterpolationDelay * _cfg.MaxExtrapMult;
				float num12 = Mathf.Clamp(num10, 0f, num11);
				desiredPos = TargetPosition + Velocity * num12;
				float num13 = ((Quaternion)(ref TargetRotation)).eulerAngles.y + AngularVelDegPerSec * num12;
				val = Quaternion.Euler(0f, num13, 0f);
			}
			Vector3 val4 = CurrentPosition - desiredPos;
			bool num14 = ((Vector3)(ref val4)).sqrMagnitude >= _cfg.TeleportDistSq;
			bool flag2 = Quaternion.Angle(CurrentRotation, val) >= _cfg.TeleportAngleDeg;
			if (num14 || flag2)
			{
				ApplyGrounding(ref desiredPos, force: true);
				CurrentPosition = desiredPos;
				CurrentRotation = val;
				t.SetPositionAndRotation(CurrentPosition, CurrentRotation);
				return;
			}
			if (_cfg.EnableGrounding)
			{
				ApplyGrounding(ref desiredPos, force: false);
			}
			float unscaledDeltaTime = Time.unscaledDeltaTime;
			Vector2 val5 = new Vector2(CurrentPosition.x, CurrentPosition.z);
			Vector2 val6 = default(Vector2);
			((Vector2)(ref val6))..ctor(desiredPos.x, desiredPos.z);
			float num15 = 1f - Mathf.Exp((0f - _cfg.InterpSpeedHorizontal) * unscaledDeltaTime);
			Vector2 val7 = Vector2.Lerp(val5, val6, num15);
			float num16 = 1f - Mathf.Exp((0f - _cfg.InterpSpeedVertical) * unscaledDeltaTime);
			float num17 = Mathf.Lerp(CurrentPosition.y, desiredPos.y, num16);
			CurrentPosition = new Vector3(val7.x, num17, val7.y);
			CurrentRotation = Quaternion.Slerp(CurrentRotation, val, num15);
			t.SetPositionAndRotation(CurrentPosition, CurrentRotation);
		}

		private void ApplyGrounding(ref Vector3 desiredPos, bool force)
		{
			//IL_003c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0041: Unknown result type (might be due to invalid IL or missing references)
			//IL_0051: Unknown result type (might be due to invalid IL or missing references)
			//IL_0056: Unknown result type (might be due to invalid IL or missing references)
			//IL_0073: Unknown result type (might be due to invalid IL or missing references)
			//IL_0090: Unknown result type (might be due to invalid IL or missing references)
			if (_cfg.GroundMask == 0)
			{
				return;
			}
			if (!force && Time.unscaledTime < _nextGroundCheckTime)
			{
				desiredPos.y = Mathf.Lerp(desiredPos.y, _lastGroundY, 0.5f);
				return;
			}
			Vector3 val = desiredPos + Vector3.up * _cfg.RaycastUp;
			float num = _cfg.RaycastUp + _cfg.RaycastDown;
			RaycastHit val2 = default(RaycastHit);
			if (Physics.Raycast(val, Vector3.down, ref val2, num, _cfg.GroundMask, (QueryTriggerInteraction)1))
			{
				float num2 = Mathf.Clamp(((RaycastHit)(ref val2)).point.y + _cfg.FootOffset - desiredPos.y, 0f - _cfg.VerticalSnapMax, _cfg.VerticalSnapMax);
				desiredPos.y += num2;
				_lastGroundY = desiredPos.y;
			}
			_nextGroundCheckTime = Time.unscaledTime + _cfg.GroundCheckInterval;
		}

		public void Teleport(in Vector3 pos, in Quaternion rotIn)
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_0006: Unknown result type (might be due to invalid IL or missing references)
			//IL_0035: Unknown result type (might be due to invalid IL or missing references)
			//IL_003a: Unknown result type (might be due to invalid IL or missing references)
			//IL_003b: Unknown result type (might be due to invalid IL or missing references)
			//IL_003c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0041: Unknown result type (might be due to invalid IL or missing references)
			//IL_0042: Unknown result type (might be due to invalid IL or missing references)
			//IL_0049: Unknown result type (might be due to invalid IL or missing references)
			//IL_004a: Unknown result type (might be due to invalid IL or missing references)
			//IL_004b: Unknown result type (might be due to invalid IL or missing references)
			//IL_004c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0051: Unknown result type (might be due to invalid IL or missing references)
			//IL_0052: Unknown result type (might be due to invalid IL or missing references)
			//IL_0058: Unknown result type (might be due to invalid IL or missing references)
			//IL_005d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0016: Unknown result type (might be due to invalid IL or missing references)
			//IL_001b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0021: Unknown result type (might be due to invalid IL or missing references)
			//IL_002c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0031: Unknown result type (might be due to invalid IL or missing references)
			Quaternion targetRotation = rotIn;
			if (_cfg.YawOnly)
			{
				Vector3 eulerAngles = ((Quaternion)(ref targetRotation)).eulerAngles;
				targetRotation = Quaternion.Euler(0f, eulerAngles.y, 0f);
			}
			CurrentPosition = (TargetPosition = pos);
			CurrentRotation = (TargetRotation = targetRotation);
			Velocity = Vector3.zero;
			AngularVelDegPerSec = 0f;
			_snapshotCount = 0;
			_snapshotHead = 0;
			HasBaseline = true;
			_lastGroundY = pos.y;
		}
	}
	public class EnemySpawnManager : IDisposable
	{
		private uint _nextEnemyNetworkId = 1u;

		public void Dispose()
		{
			_nextEnemyNetworkId = 1u;
		}

		public uint GenerateNextEnemyNetworkId()
		{
			return _nextEnemyNetworkId++;
		}

		public void BroadcastEnemySpawn(Enemy enemy)
		{
			//IL_0030: Unknown result type (might be due to invalid IL or missing references)
			//IL_0036: Expected I4, but got Unknown
			//IL_003c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0041: Unknown result type (might be due to invalid IL or missing references)
			//IL_0048: Unknown result type (might be due to invalid IL or missing references)
			//IL_004d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0051: Unknown result type (might be due to invalid IL or missing references)
			//IL_0056: Unknown result type (might be due to invalid IL or missing references)
			//IL_0060: Unknown result type (might be due to invalid IL or missing references)
			//IL_0067: Expected I4, but got Unknown
			//IL_006e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0073: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b8: Unknown result type (might be due to invalid IL or missing references)
			//IL_00bf: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c6: Unknown result type (might be due to invalid IL or missing references)
			//IL_0088: Unknown result type (might be due to invalid IL or missing references)
			//IL_008d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0091: Unknown result type (might be due to invalid IL or missing references)
			//IL_0098: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server && !((Object)(object)enemy == (Object)null))
			{
				uint enemyId = ((enemy.id != 0) ? enemy.id : GenerateNextEnemyNetworkId());
				int enemyType = (int)enemy.enemyData.enemyName;
				Vector3 position = ((Component)enemy).transform.position;
				Quaternion rotation = ((Component)enemy).transform.rotation;
				Vector3 eulerAngles = ((Quaternion)(ref rotation)).eulerAngles;
				float maxHp = enemy.maxHp;
				int flags = (int)enemy.enemyFlag;
				float extraSizeMultiplier = 1f;
				Vector2 zero = Vector2.zero;
				if (Object.op_Implicit((Object)(object)enemy.enemyMovement))
				{
					Vector3 baseVelocity = enemy.enemyMovement.baseVelocity;
					((Vector2)(ref zero))..ctor(baseVelocity.x, baseVelocity.z);
				}
				EnemySpawnedMessage tMsg = new EnemySpawnedMessage
				{
					EnemyId = enemyId,
					EnemyType = enemyType,
					Position = position,
					EulerAngles = eulerAngles,
					VelXZ = zero,
					MaxHp = maxHp,
					Flags = flags,
					extraSizeMultiplier = extraSizeMultiplier
				};
				SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
			}
		}

		public void BroadcastEnemyDamage(Enemy enemy, DamageContainer damageContainer)
		{
			//IL_003a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0044: Expected I4, but got Unknown
			//IL_0073: Unknown result type (might be due to invalid IL or missing references)
			//IL_007d: Expected I4, but got Unknown
			//IL_007f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0089: Expected I4, but got Unknown
			if (SteamNetworkManager.Mode == SteamNetworkMode.None || (Object)(object)enemy == (Object)null || damageContainer == null)
			{
				return;
			}
			uint id = enemy.id;
			if (id != 0)
			{
				EnemyDamagedMessage tMsg = new EnemyDamagedMessage
				{
					EnemyId = id,
					Damage = damageContainer.damage,
					DamageEffect = (int)damageContainer.damageEffect,
					DamageBlockedByArmor = damageContainer.damageBlockedByArmor,
					DamageSource = (damageContainer.damageSource ?? string.Empty),
					DamageProcCoefficient = damageContainer.procCoefficient,
					DamageElement = (int)damageContainer.element,
					DamageFlags = (int)damageContainer.flags,
					DamageKnockback = damageContainer.knockback,
					DamageIsCrit = damageContainer.crit,
					AttackerId = SteamUser.GetSteamID().m_SteamID
				};
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
				}
				else
				{
					SteamNetworkClient.Instance?.SendMessage(tMsg);
				}
			}
		}

		public void RegisterHostEnemy(Enemy enemy)
		{
			MatchContext.Current?.HostEnemies.RegisterHostEnemy(enemy);
		}

		public void ProcessEnemyDeath(Enemy enemy)
		{
			if (!Object.op_Implicit((Object)(object)enemy))
			{
				return;
			}
			uint id = enemy.id;
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(new EnemyDiedMessage
				{
					EnemyId = id
				});
				MatchContext.Current?.HostEnemies.UnregisterHostEnemy(id, _clientKilled: false);
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				if (enemy.IsStageBoss() && !enemy.IsFinalBoss())
				{
					OnBossDied();
				}
				SteamNetworkClient.Instance.SendMessage(new EnemyDiedMessage
				{
					EnemyId = id
				});
				MatchContext.Current?.RemoteEnemies.RemoveEnemy(id, _hostkilled: false);
			}
		}

		public void OnBossDied()
		{
			((Component)GameManager.Instance.player.minimapCamera).GetComponent<MinimapCamera>().arrowDict.Clear();
			InteractableBossSpawner val = Object.FindObjectOfType<InteractableBossSpawner>();
			if ((Object)(object)val != (Object)null)
			{
				val.portal.SetActive(true);
			}
			InteractableBossSpawner.A_BossDefeated?.Invoke(true);
		}
	}
	public class FinalBossOrbManager : IDisposable
	{
		private class OrbInfo
		{
			public uint OrbId { get; set; }

			public ulong TargetId { get; set; }

			public GameObject GameObject { get; set; }
		}

		private readonly Dictionary<ulong, OrbInfo> _orbsById = new Dictionary<ulong, OrbInfo>();

		private readonly Queue<ulong> _queuedTargetIds = new Queue<ulong>();

		private readonly Queue<(ulong targetId, uint orbId)> _pendingOrbCreation = new Queue<(ulong, uint)>();

		private uint _nextOrbId;

		public void QueueNextTarget(ulong targetId)
		{
			_queuedTargetIds.Enqueue(targetId);
		}

		public void ClearQueueNextTarget()
		{
			_queuedTargetIds.Clear();
		}

		public (ulong targetId, uint orbId)? PeekNextTarget()
		{
			if (!_queuedTargetIds.TryPeek(out var result))
			{
				return null;
			}
			uint item = ++_nextOrbId;
			_pendingOrbCreation.Enqueue((result, item));
			return (result, item);
		}

		public (ulong targetId, uint orbId)? GetNextTargetAndOrbId()
		{
			if (_pendingOrbCreation.TryDequeue(out (ulong, uint) result))
			{
				return result;
			}
			return null;
		}

		public void SetOrbTarget(ulong targetId, GameObject target, uint orbId)
		{
			_orbsById[orbId] = new OrbInfo
			{
				OrbId = orbId,
				TargetId = targetId,
				GameObject = target
			};
		}

		public void Dispose()
		{
			_orbsById.Clear();
			_queuedTargetIds.Clear();
			_pendingOrbCreation.Clear();
			_nextOrbId = 0u;
		}

		public bool ContainsOrb(GameObject go)
		{
			return _orbsById.Values.Any((OrbInfo orb) => (Object)(object)orb.GameObject == (Object)(object)go);
		}

		public IEnumerable<BossOrbModel> GetAllOrbs()
		{
			return from orb in _orbsById.Values
				where (Object)(object)orb.GameObject != (Object)null
				select new BossOrbModel
				{
					Id = orb.OrbId,
					Position = orb.GameObject.transform.position
				};
		}

		public GameObject GetOrbById(uint id)
		{
			if (!_orbsById.TryGetValue(id, out var value))
			{
				return null;
			}
			return value.GameObject;
		}

		public ulong? RemoveOrb(GameObject go)
		{
			KeyValuePair<ulong, OrbInfo> keyValuePair = _orbsById.FirstOrDefault((KeyValuePair<ulong, OrbInfo> kv) => (Object)(object)kv.Value.GameObject == (Object)(object)go);
			if (keyValuePair.Value == null)
			{
				return null;
			}
			_orbsById.Remove(keyValuePair.Key);
			return keyValuePair.Key;
		}

		public ulong? GetTargetIdByReference(GameObject go)
		{
			return _orbsById.Values.FirstOrDefault((OrbInfo o) => (Object)(object)o.GameObject == (Object)(object)go)?.TargetId;
		}

		public void SendOrbUpdates()
		{
			//IL_0060: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			FinalBossOrbsUpdateMessage finalBossOrbsUpdateMessage = new FinalBossOrbsUpdateMessage();
			foreach (OrbInfo value in _orbsById.Values)
			{
				if ((Object)(object)value.GameObject != (Object)null)
				{
					finalBossOrbsUpdateMessage.Orbs.Add(new BossOrbModel
					{
						Id = value.OrbId,
						Position = value.GameObject.transform.position
					});
				}
			}
			if (finalBossOrbsUpdateMessage.Orbs.Count != 0)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(finalBossOrbsUpdateMessage);
			}
		}
	}
	public class HostEnemyManager : IDisposable
	{
		private struct CellKey : IEquatable<CellKey>
		{
			public readonly int X;

			public readonly int Z;

			public CellKey(int x, int z)
			{
				X = x;
				Z = z;
			}

			public bool Equals(CellKey other)
			{
				if (X == other.X)
				{
					return Z == other.Z;
				}
				return false;
			}

			public override bool Equals(object obj)
			{
				if (obj is CellKey other)
				{
					return Equals(other);
				}
				return false;
			}

			public override int GetHashCode()
			{
				return (X * 73856093) ^ (Z * 19349663);
			}
		}

		private struct SentState
		{
			public Vector3 Pos;

			public float YawDeg;

			public Vector2 VelXZ;

			public float AngVelDeg;

			public uint Seq;

			public float ServerTime;
		}

		private const int MAX_ENEMIES = 4000;

		private readonly Enemy[] _syncedEnemies = (Enemy[])(object)new Enemy[4000];

		private readonly HashSet<uint> _activeEnemyIds = new HashSet<uint>();

		private readonly Dictionary<CellKey, HashSet<Enemy>> _grid = new Dictionary<CellKey, HashSet<Enemy>>();

		private readonly CellKey?[] _enemyCells = new CellKey?[4000];

		private const float CELL_SIZE = 100f;

		private readonly List<Enemy> _statBatchScratch = new List<Enemy>(512);

		private readonly List<Enemy> _movementBatchScratch = new List<Enemy>(512);

		private float _lastStatBatchTime;

		private const float STAT_BATCH_INTERVAL = 0.05f;

		private float _lastMovementBatchTime;

		private const float MOVEMENT_BATCH_INTERVAL = 0.1f;

		private int _statPhase;

		private const int NUM_BATCH_PHASES = 10;

		private readonly EnemyStateBatchMessage _movementBatchMsg = new EnemyStateBatchMessage
		{
			States = new List<EnemyStateBatchMessage.EnemyState>(256)
		};

		private readonly SentState?[] _lastSent = new SentState?[4000];

		private readonly EEnemyFlag?[] _lastEnemyFlags = new EEnemyFlag?[4000];

		private readonly uint[] _sequenceCounters = new uint[4000];

		private const float DR_MAX_POS_ERR = 0.15f;

		private const float DR_MAX_YAW_ERR_DEG = 5f;

		private const float DR_HEARTBEAT_SEC = 0.1f;

		public void RegisterHostEnemy(Enemy enemy)
		{
			if ((Object)(object)enemy == (Object)null)
			{
				return;
			}
			uint id = enemy.id;
			if (id < 4000)
			{
				if (!Object.op_Implicit((Object)(object)_syncedEnemies[id]))
				{
					_activeEnemyIds.Add(id);
				}
				_syncedEnemies[id] = enemy;
				UpdateEnemyInGrid(enemy);
			}
		}

		public void UnregisterHostEnemy(uint id, bool _clientKilled)
		{
			if (id < 4000)
			{
				Enemy val = _syncedEnemies[id];
				EnemyPatches.EnemyMovement_GetTargetPosition_Patch.OnEnemyDied(id);
				if (Object.op_Implicit((Object)(object)val))
				{
					RemoveEnemyFromGrid(val);
				}
				if (_clientKilled)
				{
					val.EnemyDied();
				}
				if (Object.op_Implicit((Object)(object)_syncedEnemies[id]))
				{
					_syncedEnemies[id] = null;
					_activeEnemyIds.Remove(id);
				}
				_lastSent[id] = null;
				_lastEnemyFlags[id] = null;
				_sequenceCounters[id] = 0u;
				MatchContext.Current?.SmartSpatial.UnregisterEnemy(id);
			}
		}

		public Enemy GetTrackedEnemy(uint id)
		{
			if (id >= 4000)
			{
				return null;
			}
			return _syncedEnemies[id];
		}

		public void Dispose()
		{
			Array.Clear(_syncedEnemies, 0, 4000);
			_activeEnemyIds.Clear();
			Array.Clear(_lastSent, 0, 4000);
			Array.Clear(_lastEnemyFlags, 0, 4000);
			Array.Clear(_sequenceCounters, 0, 4000);
			_grid.Clear();
			Array.Clear(_enemyCells, 0, 4000);
			_statBatchScratch.Clear();
			_movementBatchScratch.Clear();
			_lastStatBatchTime = 0f;
			_lastMovementBatchTime = 0f;
			_statPhase = 0;
		}

		public void HostNetworkTick()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				float unscaledTime = Time.unscaledTime;
				MatchContext.Current?.SmartSpatial.Update();
				if (unscaledTime - _lastStatBatchTime >= 0.05f)
				{
					ProcessStatBatch(unscaledTime);
					_lastStatBatchTime = unscaledTime;
				}
				if (unscaledTime - _lastMovementBatchTime >= 0.1f)
				{
					ProcessMovementBatch(unscaledTime);
					_lastMovementBatchTime = unscaledTime;
				}
			}
		}

		private void ProcessStatBatch(float serverTime)
		{
			_statPhase = (_statPhase + 1) % 10;
		}

		private void ProcessMovementBatch(float serverTime)
		{
			//IL_0064: Unknown result type (might be due to invalid IL or missing references)
			//IL_0069: Unknown result type (might be due to invalid IL or missing references)
			//IL_0072: Unknown result type (might be due to invalid IL or missing references)
			//IL_0077: Unknown result type (might be due to invalid IL or missing references)
			//IL_007b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0087: Unknown result type (might be due to invalid IL or missing references)
			//IL_008c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0125: Unknown result type (might be due to invalid IL or missing references)
			//IL_012a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0135: Unknown result type (might be due to invalid IL or missing references)
			//IL_0139: Unknown result type (might be due to invalid IL or missing references)
			//IL_013f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0161: Unknown result type (might be due to invalid IL or missing references)
			//IL_0174: Unknown result type (might be due to invalid IL or missing references)
			//IL_0187: Unknown result type (might be due to invalid IL or missing references)
			//IL_01a8: Unknown result type (might be due to invalid IL or missing references)
			//IL_01bb: Unknown result type (might be due to invalid IL or missing references)
			//IL_021a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0224: Expected I4, but got Unknown
			//IL_0107: Unknown result type (might be due to invalid IL or missing references)
			//IL_010c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0110: Unknown result type (might be due to invalid IL or missing references)
			//IL_0117: Unknown result type (might be due to invalid IL or missing references)
			//IL_029e: Unknown result type (might be due to invalid IL or missing references)
			//IL_02a0: Unknown result type (might be due to invalid IL or missing references)
			//IL_02b0: Unknown result type (might be due to invalid IL or missing references)
			//IL_02b2: Unknown result type (might be due to invalid IL or missing references)
			//IL_02eb: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ce: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d3: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d7: Unknown result type (might be due to invalid IL or missing references)
			//IL_00de: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ec: Unknown result type (might be due to invalid IL or missing references)
			_movementBatchScratch.Clear();
			EnemyStateBatchMessage movementBatchMsg = _movementBatchMsg;
			movementBatchMsg.States.Clear();
			int num = 0;
			foreach (uint activeEnemyId in _activeEnemyIds)
			{
				Enemy val = _syncedEnemies[activeEnemyId];
				if (!Object.op_Implicit((Object)(object)val))
				{
					continue;
				}
				bool num2 = val.CanMove();
				UpdateEnemyInGrid(val);
				Vector3 position = ((Component)val).transform.position;
				Quaternion rotation = ((Component)val).transform.rotation;
				float y = ((Quaternion)(ref rotation)).eulerAngles.y;
				Vector2 zero = Vector2.zero;
				float num3 = 0f;
				if (num2)
				{
					if (Object.op_Implicit((Object)(object)val.enemyMovement))
					{
						Rigidbody rb = val.enemyMovement.rb;
						if ((Object)(object)rb != (Object)null && !rb.isKinematic)
						{
							Vector3 velocity = rb.velocity;
							((Vector2)(ref zero))..ctor(velocity.x, velocity.z);
							num3 = rb.angularVelocity.y * 57.29578f;
						}
						else
						{
							Vector3 baseVelocity = val.enemyMovement.baseVelocity;
							((Vector2)(ref zero))..ctor(baseVelocity.x, baseVelocity.z);
						}
					}
				}
				else
				{
					zero = Vector2.zero;
					num3 = 0f;
				}
				if (ShouldSendEnemyState(activeEnemyId, position, y, zero, num3, val.enemyFlag, serverTime))
				{
					EnemyStateBatchMessage.EnemyState item = new EnemyStateBatchMessage.EnemyState
					{
						EnemyId = activeEnemyId,
						PosX = Quant.QPos(position.x),
						PosY = Quant.QPos(position.y),
						PosZ = Quant.QPos(position.z),
						YawQuantized = Quant.QYaw(y),
						VelX = Quant.QVel(zero.x),
						VelZ = Quant.QVel(zero.y),
						AngVelQuantized = Quant.QAngVel(num3),
						Hp = (ushort)Mathf.Clamp(val.hp, 0f, 65535f),
						MaxHp = (ushort)Mathf.Clamp(val.maxHp, 0f, 65535f),
						Flags = (int)val.enemyFlag,
						ServerTime = serverTime,
						Seq = _sequenceCounters[activeEnemyId]++
					};
					if (num + 40 > 1150 && movementBatchMsg.States.Count > 0)
					{
						SendBatch(movementBatchMsg);
						movementBatchMsg.States.Clear();
						num = 0;
					}
					movementBatchMsg.States.Add(item);
					num += 40;
					_lastSent[activeEnemyId] = new SentState
					{
						Pos = position,
						YawDeg = y,
						VelXZ = zero,
						AngVelDeg = num3,
						Seq = item.Seq,
						ServerTime = serverTime
					};
					_lastEnemyFlags[activeEnemyId] = val.enemyFlag;
				}
			}
			if (movementBatchMsg.States.Count > 0)
			{
				SendBatch(movementBatchMsg);
			}
		}

		private bool ShouldSendEnemyState(uint id, Vector3 pos, float yawDeg, Vector2 velXZ, float angVelDeg, EEnemyFlag flags, float serverTime)
		{
			//IL_0046: Unknown result type (might be due to invalid IL or missing references)
			//IL_0048: Unknown result type (might be due to invalid IL or missing references)
			//IL_004b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0050: Unknown result type (might be due to invalid IL or missing references)
			//IL_005f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0061: Unknown result type (might be due to invalid IL or missing references)
			//IL_0066: Unknown result type (might be due to invalid IL or missing references)
			//IL_0093: Unknown result type (might be due to invalid IL or missing references)
			//IL_0096: Unknown result type (might be due to invalid IL or missing references)
			//IL_009b: Unknown result type (might be due to invalid IL or missing references)
			if (!_lastSent[id].HasValue)
			{
				return true;
			}
			SentState value = _lastSent[id].Value;
			if (serverTime - value.ServerTime > 0.1f)
			{
				return true;
			}
			if (_lastEnemyFlags[id] != (EEnemyFlag?)flags)
			{
				return true;
			}
			if (Vector3.SqrMagnitude(pos - value.Pos) > 0.0225f)
			{
				return true;
			}
			if (Mathf.Abs(Mathf.DeltaAngle(yawDeg, value.YawDeg)) > 5f)
			{
				return true;
			}
			if (Vector2.SqrMagnitude(velXZ - value.VelXZ) > 0.25f)
			{
				return true;
			}
			if (Mathf.Abs(angVelDeg - value.AngVelDeg) > 5f)
			{
				return true;
			}
			return false;
		}

		private void SendBatch(EnemyStateBatchMessage batch)
		{
			if (SteamNetworkServer.Instance != null)
			{
				SteamNetworkServer.Instance.BroadcastMessage(batch);
			}
		}

		private CellKey CellFor(in Vector3 pos)
		{
			return new CellKey(Mathf.FloorToInt(pos.x / 100f), Mathf.FloorToInt(pos.z / 100f));
		}

		private bool UpdateEnemyInGridIfNeeded(Enemy enemy)
		{
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			//IL_002a: Unknown result type (might be due to invalid IL or missing references)
			if ((Object)(object)enemy == (Object)null || enemy.id >= 4000)
			{
				return false;
			}
			uint id = enemy.id;
			CellKey cellKey = CellFor(((Component)enemy).transform.position);
			if (_enemyCells[id].HasValue && _enemyCells[id].Value.Equals(cellKey))
			{
				return false;
			}
			if (_enemyCells[id].HasValue)
			{
				CellKey value = _enemyCells[id].Value;
				if (_grid.TryGetValue(value, out var value2))
				{
					value2.Remove(enemy);
					if (value2.Count == 0)
					{
						_grid.Remove(value);
					}
				}
			}
			if (!_grid.TryGetValue(cellKey, out var value3))
			{
				value3 = new HashSet<Enemy>();
				_grid[cellKey] = value3;
			}
			value3.Add(enemy);
			_enemyCells[id] = cellKey;
			return true;
		}

		private void UpdateEnemyInGrid(Enemy enemy)
		{
			UpdateEnemyInGridIfNeeded(enemy);
		}

		private void RemoveEnemyFromGrid(Enemy enemy)
		{
			if (!Object.op_Implicit((Object)(object)enemy) || enemy.id >= 4000)
			{
				return;
			}
			uint id = enemy.id;
			if (!_enemyCells[id].HasValue)
			{
				return;
			}
			CellKey value = _enemyCells[id].Value;
			if (_grid.TryGetValue(value, out var value2))
			{
				value2.Remove(enemy);
				if (value2.Count == 0)
				{
					_grid.Remove(value);
				}
			}
			_enemyCells[id] = null;
		}
	}
	public class RemoteEnemyManager : IDisposable
	{
		private struct ActiveEnemy : IEquatable<ActiveEnemy>
		{
			public uint Id;

			public EnemyInterpolatedTransform Interp;

			public Enemy EnemyRef;

			public bool Equals(ActiveEnemy other)
			{
				return Id == other.Id;
			}

			public override bool Equals(object obj)
			{
				if (obj is ActiveEnemy other)
				{
					return Equals(other);
				}
				return false;
			}

			public override int GetHashCode()
			{
				return Id.GetHashCode();
			}
		}

		private readonly Dictionary<uint, ActiveEnemy> _activeEnemiesMap = new Dictionary<uint, ActiveEnemy>();

		private readonly List<ActiveEnemy> _activeEnemiesList = new List<ActiveEnemy>(64);

		private readonly List<uint> _deadIdsScratch = new List<uint>(32);

		public void SpawnRemoteEnemy(uint id, int type, Vector3 pos, Vector3 euler, Vector2 velXZ, float maxHp, EEnemyFlag flags, float extraSizeMultiplier)
		{
			//IL_0032: Unknown result type (might be due to invalid IL or missing references)
			//IL_0035: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d6: Unknown result type (might be due to invalid IL or missing references)
			//IL_00f9: Unknown result type (might be due to invalid IL or missing references)
			//IL_00fb: Unknown result type (might be due to invalid IL or missing references)
			//IL_0100: Unknown result type (might be due to invalid IL or missing references)
			//IL_013d: Unknown result type (might be due to invalid IL or missing references)
			//IL_013f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0144: Unknown result type (might be due to invalid IL or missing references)
			//IL_0148: Unknown result type (might be due to invalid IL or missing references)
			//IL_0154: Unknown result type (might be due to invalid IL or missing references)
			//IL_015b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0160: Unknown result type (might be due to invalid IL or missing references)
			if (_activeEnemiesMap.ContainsKey(id))
			{
				return;
			}
			EnemyData enemyData = DataManager.Instance.GetEnemyData((EEnemy)type);
			if (Object.op_Implicit((Object)(object)enemyData))
			{
				EnemyPatches.SetSpawningFromNetwork(value: true);
				Enemy val = null;
				try
				{
					val = EnemyManager.Instance.SpawnEnemy(enemyData, pos, 0, true, flags, true, extraSizeMultiplier);
				}
				finally
				{
					EnemyPatches.SetSpawningFromNetwork(value: false);
				}
				if (!Object.op_Implicit((Object)(object)val))
				{
					ModLogger.Error($"[RemoteEnemyManager] Failed to spawn game enemy for ID {id}, Type {type}.");
					return;
				}
				ResetEnemyRendererState(val, enemyData);
				val.id = id;
				val.hp = maxHp;
				val.controlHp = maxHp;
				val.maxHp = maxHp;
				val._hp_k__BackingField = maxHp;
				EnemyInterpolatedTransform enemyInterpolatedTransform = new EnemyInterpolatedTransform(new EnemyInterpolatedTransform.Config
				{
					GroundMask = LayerMask.op_Implicit(GameManager.Instance.whatIsGround),
					FootOffset = 0.05f
				});
				enemyInterpolatedTransform.Teleport(in pos, Quaternion.Euler(euler));
				MatchContext current = MatchContext.Current;
				float serverTime = ((current != null && current.TimeSync.IsInitialized) ? MatchContext.Current.TimeSync.CurrentServerTime : Time.unscaledTime);
				enemyInterpolatedTransform.SetTarget(serverTime, 0u, in pos, Quaternion.Euler(euler), new Vector3(velXZ.x, 0f, velXZ.y));
				ActiveEnemy activeEnemy = new ActiveEnemy
				{
					Id = id,
					Interp = enemyInterpolatedTransform,
					EnemyRef = val
				};
				_activeEnemiesMap[id] = activeEnemy;
				_activeEnemiesList.Add(activeEnemy);
			}
		}

		private void ResetEnemyRendererState(Enemy enemy, EnemyData data)
		{
			try
			{
				EnemyDissolve component = ((Component)enemy).gameObject.GetComponent<EnemyDissolve>();
				if ((Object)(object)component != (Object)null)
				{
					component.Reset();
				}
				EnemyRenderer component2 = ((Component)enemy).gameObject.GetComponent<EnemyRenderer>();
				if ((Object)(object)component2 != (Object)null)
				{
					component2.Set(data);
					component2.RefreshColor((EDebuff)0);
				}
				if ((Object)(object)enemy.renderer != (Object)null && (Object)(object)data.material != (Object)null)
				{
					enemy.renderer.sharedMaterial = data.material;
				}
			}
			catch (Exception)
			{
			}
		}

		public void RemoveEnemy(uint id, bool _hostkilled)
		{
			if (_activeEnemiesMap.TryGetValue(id, out var value))
			{
				if (_hostkilled)
				{
					value.EnemyRef.EnemyDied();
				}
				_activeEnemiesMap.Remove(id);
				_activeEnemiesList.Remove(value);
			}
		}

		public bool HasEnemy(uint id)
		{
			return _activeEnemiesMap.ContainsKey(id);
		}

		public Enemy GetEnemy(uint id)
		{
			if (_activeEnemiesMap.TryGetValue(id, out var value))
			{
				return value.EnemyRef;
			}
			return null;
		}

		public void Update()
		{
			int count = _activeEnemiesList.Count;
			for (int i = 0; i < count; i++)
			{
				ActiveEnemy activeEnemy = _activeEnemiesList[i];
				if (!Object.op_Implicit((Object)(object)activeEnemy.EnemyRef))
				{
					_deadIdsScratch.Add(activeEnemy.Id);
				}
				else
				{
					activeEnemy.Interp.Update(((Component)activeEnemy.EnemyRef).transform);
				}
			}
			if (_deadIdsScratch.Count <= 0)
			{
				return;
			}
			foreach (uint item in _deadIdsScratch)
			{
				RemoveEnemy(item, _hostkilled: false);
			}
			_deadIdsScratch.Clear();
		}

		public void OnEnemyStateSnapshot(uint enemyId, short posX, short posY, short posZ, byte yawQuantized, sbyte velX, sbyte velZ, sbyte angVelQuantized, ushort hp, ushort maxHp, float serverTime, uint seq)
		{
			//IL_003e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0043: Unknown result type (might be due to invalid IL or missing references)
			if (!_activeEnemiesMap.TryGetValue(enemyId, out var value))
			{
				return;
			}
			Vector3 pos = default(Vector3);
			((Vector3)(ref pos))..ctor(Quant.DPos(posX), Quant.DPos(posY), Quant.DPos(posZ));
			float num = Quant.DYaw(yawQuantized);
			Quaternion rotIn = Quaternion.Euler(0f, num, 0f);
			Vector3 velIn = default(Vector3);
			((Vector3)(ref velIn))..ctor(Quant.DVel(velX), 0f, Quant.DVel(velZ));
			float angVelDegPerSec = Quant.DAngVel(angVelQuantized);
			_ = ((Vector3)(ref velIn)).sqrMagnitude;
			_ = 0.01f;
			value.Interp.SetTarget(serverTime, seq, in pos, in rotIn, in velIn, angVelDegPerSec);
			if (Object.op_Implicit((Object)(object)value.EnemyRef))
			{
				float hp2 = value.EnemyRef.hp;
				float num2 = (int)hp;
				if (num2 < hp2)
				{
					value.EnemyRef.hp = num2;
				}
				else if (num2 > hp2 + 5f)
				{
					value.EnemyRef.hp = num2;
				}
				value.EnemyRef.maxHp = (int)maxHp;
			}
		}

		public void Dispose()
		{
			_activeEnemiesMap.Clear();
			_activeEnemiesList.Clear();
			_deadIdsScratch.Clear();
		}
	}
	public class SmartSpatialTargeting : IDisposable
	{
		private struct TargetInfo
		{
			public Vector3 CachedPosition;

			public float DistanceToTarget;

			public int CurrentTier;
		}

		private struct PlayerSpatialData
		{
			public Vector3 Position;

			public Transform Transform;

			public Rigidbody Rigidbody;
		}

		private struct CellKey : IEquatable<CellKey>
		{
			public readonly int X;

			public readonly int Z;

			public CellKey(int x, int z)
			{
				X = x;
				Z = z;
			}

			public bool Equals(CellKey other)
			{
				if (X == other.X)
				{
					return Z == other.Z;
				}
				return false;
			}

			public override bool Equals(object obj)
			{
				if (obj is CellKey other)
				{
					return Equals(other);
				}
				return false;
			}

			public override int GetHashCode()
			{
				return (X * 73856093) ^ (Z * 19349663);
			}
		}

		private struct DistanceSortItem : IComparable<DistanceSortItem>
		{
			public uint Id;

			public float Distance;

			public int CompareTo(DistanceSortItem other)
			{
				return other.Distance.CompareTo(Distance);
			}
		}

		private const float TIER_1_DISTANCE = 15f;

		private const float TIER_2_DISTANCE = 40f;

		private const float TIER_1_UPDATE_RATE = 0.33f;

		private const float TIER_2_UPDATE_RATE = 1f;

		private const float TIER_3_UPDATE_RATE = 3f;

		private const int TIER_1_ENEMY_CAP = 35;

		private const float CELL_SIZE = 100f;

		private readonly Dictionary<uint, TargetInfo> _enemyTargets = new Dictionary<uint, TargetInfo>();

		private readonly List<uint>[] _tierBuckets = new List<uint>[3]
		{
			new List<uint>(256),
			new List<uint>(512),
			new List<uint>(512)
		};

		private readonly Dictionary<CellKey, List<PlayerSpatialData>> _playerGrid = new Dictionary<CellKey, List<PlayerSpatialData>>();

		private readonly Stack<List<PlayerSpatialData>> _playerGridListPool = new Stack<List<PlayerSpatialData>>(16);

		private readonly List<PlayerSpatialData> _allPlayers = new List<PlayerSpatialData>(16);

		private readonly List<RemotePlayerManager.PlayerTarget> _tempPlayerTargets = new List<RemotePlayerManager.PlayerTarget>(16);

		private readonly List<PlayerSpatialData> _nearbyPlayersBuffer = new List<PlayerSpatialData>(16);

		private float _lastTier1Update;

		private float _lastTier2Update;

		private float _lastTier3Update;

		private readonly List<DistanceSortItem> _demoteSortBuffer = new List<DistanceSortItem>(128);

		public void RegisterEnemy(Enemy enemy)
		{
			//IL_0039: Unknown result type (might be due to invalid IL or missing references)
			//IL_003e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0040: Unknown result type (might be due to invalid IL or missing references)
			//IL_006d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0076: Unknown result type (might be due to invalid IL or missing references)
			//IL_007b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0080: Unknown result type (might be due to invalid IL or missing references)
			//IL_00db: Unknown result type (might be due to invalid IL or missing references)
			//IL_00e0: Unknown result type (might be due to invalid IL or missing references)
			if ((Object)(object)enemy == (Object)null || enemy.id == 0)
			{
				return;
			}
			if (_allPlayers.Count == 0)
			{
				RefreshPlayerGrid();
			}
			if (_allPlayers.Count == 0)
			{
				return;
			}
			Vector3 position = ((Component)enemy).transform.position;
			CellKey center = CellFor(position);
			List<PlayerSpatialData> list = GetPlayersInCellRange(center, 1);
			if (list.Count == 0)
			{
				list = _allPlayers;
			}
			float num = float.MaxValue;
			int index = 0;
			for (int i = 0; i < list.Count; i++)
			{
				Vector3 val = position - list[i].Position;
				float sqrMagnitude = ((Vector3)(ref val)).sqrMagnitude;
				if (sqrMagnitude < num)
				{
					num = sqrMagnitude;
					index = i;
				}
			}
			PlayerSpatialData playerSpatialData = list[index];
			float num2 = Mathf.Sqrt(num);
			int tierForDistance = GetTierForDistance(num2);
			_enemyTargets[enemy.id] = new TargetInfo
			{
				CachedPosition = playerSpatialData.Position,
				DistanceToTarget = num2,
				CurrentTier = tierForDistance
			};
			_tierBuckets[tierForDistance].Add(enemy.id);
		}

		public void UnregisterEnemy(uint enemyId)
		{
			if (_enemyTargets.TryGetValue(enemyId, out var value))
			{
				_tierBuckets[value.CurrentTier].Remove(enemyId);
				_enemyTargets.Remove(enemyId);
			}
		}

		public bool TryGetTargetPosition(uint enemyId, out Vector3 position)
		{
			//IL_001f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0024: Unknown result type (might be due to invalid IL or missing references)
			//IL_0012: Unknown result type (might be due to invalid IL or missing references)
			//IL_0017: Unknown result type (might be due to invalid IL or missing references)
			if (_enemyTargets.TryGetValue(enemyId, out var value))
			{
				position = value.CachedPosition;
				return true;
			}
			position = Vector3.zero;
			return false;
		}

		public void InvalidateTarget(uint enemyId)
		{
			if (_enemyTargets.ContainsKey(enemyId))
			{
				Enemy val = MatchContext.Current?.HostEnemies.GetTrackedEnemy(enemyId);
				if (Object.op_Implicit((Object)(object)val))
				{
					RefreshPlayerGrid();
					RecalculateTarget(enemyId, val);
				}
			}
		}

		public void Update()
		{
			float unscaledTime = Time.unscaledTime;
			RefreshPlayerGrid();
			if (unscaledTime - _lastTier1Update >= 0.33f)
			{
				UpdateTier(0);
				_lastTier1Update = unscaledTime;
			}
			if (unscaledTime - _lastTier2Update >= 1f)
			{
				UpdateTier(1);
				_lastTier2Update = unscaledTime;
			}
			if (unscaledTime - _lastTier3Update >= 3f)
			{
				UpdateTier(2);
				_lastTier3Update = unscaledTime;
			}
		}

		public void Dispose()
		{
			_enemyTargets.Clear();
			_playerGrid.Clear();
			_allPlayers.Clear();
			for (int i = 0; i < _tierBuckets.Length; i++)
			{
				_tierBuckets[i].Clear();
			}
			_lastTier1Update = 0f;
			_lastTier2Update = 0f;
			_lastTier3Update = 0f;
		}

		private void RefreshPlayerGrid()
		{
			//IL_00bb: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c0: Unknown result type (might be due to invalid IL or missing references)
			//IL_00f3: Unknown result type (might be due to invalid IL or missing references)
			foreach (List<PlayerSpatialData> value2 in _playerGrid.Values)
			{
				value2.Clear();
				_playerGridListPool.Push(value2);
			}
			_playerGrid.Clear();
			_allPlayers.Clear();
			_tempPlayerTargets.Clear();
			MatchContext.Current?.RemotePlayers.FillAllPlayerTargets(_tempPlayerTargets);
			foreach (RemotePlayerManager.PlayerTarget tempPlayerTarget in _tempPlayerTargets)
			{
				if (Object.op_Implicit((Object)(object)tempPlayerTarget.Transform))
				{
					PlayerSpatialData item = new PlayerSpatialData
					{
						Position = tempPlayerTarget.Transform.position,
						Transform = tempPlayerTarget.Transform,
						Rigidbody = tempPlayerTarget.Rigidbody
					};
					_allPlayers.Add(item);
					CellKey key = CellFor(item.Position);
					if (!_playerGrid.TryGetValue(key, out var value))
					{
						value = ((_playerGridListPool.Count > 0) ? _playerGridListPool.Pop() : new List<PlayerSpatialData>(4));
						_playerGrid[key] = value;
					}
					value.Add(item);
				}
			}
		}

		private void UpdateTier(int tier)
		{
			//IL_0080: Unknown result type (might be due to invalid IL or missing references)
			//IL_0085: Unknown result type (might be due to invalid IL or missing references)
			//IL_0088: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c6: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d1: Unknown result type (might be due to invalid IL or missing references)
			//IL_00d6: Unknown result type (might be due to invalid IL or missing references)
			//IL_00db: Unknown result type (might be due to invalid IL or missing references)
			//IL_0136: Unknown result type (might be due to invalid IL or missing references)
			//IL_013b: Unknown result type (might be due to invalid IL or missing references)
			if (_allPlayers.Count == 0)
			{
				return;
			}
			List<uint> list = _tierBuckets[tier];
			if (tier == 0 && list.Count > 35)
			{
				DemoteExcessTier1Enemies();
			}
			for (int num = list.Count - 1; num >= 0; num--)
			{
				uint num2 = list[num];
				Enemy val = MatchContext.Current?.HostEnemies.GetTrackedEnemy(num2);
				if (!Object.op_Implicit((Object)(object)val))
				{
					list.RemoveAt(num);
					_enemyTargets.Remove(num2);
				}
				else
				{
					Vector3 position = ((Component)val).transform.position;
					CellKey center = CellFor(position);
					int range = ((tier == 0) ? 1 : 2);
					List<PlayerSpatialData> list2 = GetPlayersInCellRange(center, range);
					if (list2.Count == 0)
					{
						list2 = _allPlayers;
					}
					float num3 = float.MaxValue;
					int index = 0;
					for (int i = 0; i < list2.Count; i++)
					{
						Vector3 val2 = position - list2[i].Position;
						float sqrMagnitude = ((Vector3)(ref val2)).sqrMagnitude;
						if (sqrMagnitude < num3)
						{
							num3 = sqrMagnitude;
							index = i;
						}
					}
					PlayerSpatialData playerSpatialData = list2[index];
					float num4 = Mathf.Sqrt(num3);
					int tierForDistance = GetTierForDistance(num4);
					_enemyTargets[num2] = new TargetInfo
					{
						CachedPosition = playerSpatialData.Position,
						DistanceToTarget = num4,
						CurrentTier = tierForDistance
					};
					if (tierForDistance != tier)
					{
						list.RemoveAt(num);
						_tierBuckets[tierForDistance].Add(num2);
					}
				}
			}
		}

		private int RecalculateTarget(uint enemyId, Enemy enemy)
		{
			//IL_0006: Unknown result type (might be due to invalid IL or missing references)
			//IL_000b: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_003a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0043: Unknown result type (might be due to invalid IL or missing references)
			//IL_0048: Unknown result type (might be due to invalid IL or missing references)
			//IL_004d: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a3: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a8: Unknown result type (might be due to invalid IL or missing references)
			Vector3 position = ((Component)enemy).transform.position;
			CellKey center = CellFor(position);
			List<PlayerSpatialData> list = GetPlayersInCellRange(center, 2);
			if (list.Count == 0)
			{
				list = _allPlayers;
			}
			float num = float.MaxValue;
			int index = 0;
			for (int i = 0; i < list.Count; i++)
			{
				Vector3 val = position - list[i].Position;
				float sqrMagnitude = ((Vector3)(ref val)).sqrMagnitude;
				if (sqrMagnitude < num)
				{
					num = sqrMagnitude;
					index = i;
				}
			}
			PlayerSpatialData playerSpatialData = list[index];
			float num2 = Mathf.Sqrt(num);
			int tierForDistance = GetTierForDistance(num2);
			_enemyTargets[enemyId] = new TargetInfo
			{
				CachedPosition = playerSpatialData.Position,
				DistanceToTarget = num2,
				CurrentTier = tierForDistance
			};
			return tierForDistance;
		}

		private int DemoteExcessTier1Enemies()
		{
			List<uint> list = _tierBuckets[0];
			int num = list.Count - 35;
			if (num <= 0)
			{
				return 0;
			}
			_demoteSortBuffer.Clear();
			for (int i = 0; i < list.Count; i++)
			{
				uint num2 = list[i];
				if (_enemyTargets.TryGetValue(num2, out var value))
				{
					_demoteSortBuffer.Add(new DistanceSortItem
					{
						Id = num2,
						Distance = value.DistanceToTarget
					});
				}
			}
			_demoteSortBuffer.Sort();
			int num3 = 0;
			for (int j = 0; j < num && j < _demoteSortBuffer.Count; j++)
			{
				uint id = _demoteSortBuffer[j].Id;
				list.Remove(id);
				_tierBuckets[1].Add(id);
				TargetInfo value2 = _enemyTargets[id];
				value2.CurrentTier = 1;
				_enemyTargets[id] = value2;
				num3++;
			}
			return num3;
		}

		private List<PlayerSpatialData> GetPlayersInCellRange(CellKey center, int range)
		{
			_nearbyPlayersBuffer.Clear();
			for (int i = -range; i <= range; i++)
			{
				for (int j = -range; j <= range; j++)
				{
					CellKey key = new CellKey(center.X + i, center.Z + j);
					if (_playerGrid.TryGetValue(key, out var value))
					{
						_nearbyPlayersBuffer.AddRange(value);
					}
				}
			}
			return _nearbyPlayersBuffer;
		}

		private int GetTierForDistance(float distance)
		{
			if (distance < 15f)
			{
				return 0;
			}
			if (distance < 40f)
			{
				return 1;
			}
			return 2;
		}

		private CellKey CellFor(Vector3 pos)
		{
			//IL_0000: Unknown result type (might be due to invalid IL or missing references)
			//IL_0011: Unknown result type (might be due to invalid IL or missing references)
			return new CellKey(Mathf.FloorToInt(pos.x / 100f), Mathf.FloorToInt(pos.z / 100f));
		}
	}
}
namespace Megabonk.BonkWithFriends.Localization
{
	internal static class LocalizationManager
	{
		internal const string Prefix = "BonkWithFriendsMod";

		internal const string MainMenuTable = "Main Menu";

		internal static MainMenuTable MainMenu;

		internal static bool Initialized { get; private set; }

		internal static void Setup()
		{
			if (!Initialized)
			{
				MainMenu = new MainMenuTable();
				Initialized = true;
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.Localization.Tables
{
	internal class CustomLocalizationTable
	{
		internal StringTable StringTable { get; private set; }

		internal string TableName { get; private set; }

		internal CustomLocalizationTable(string tableName)
		{
			TableName = tableName;
			StringTable = ((LocalizedDatabase<StringTable, StringTableEntry>)(object)LocalizationSettings.StringDatabase).GetTable(TableReference.op_Implicit(TableName), (Locale)null);
		}

		internal StringTableEntry GetEntry(string key)
		{
			return ((DetailedLocalizationTable<StringTableEntry>)(object)StringTable).GetEntry(key);
		}

		internal StringTableEntry AddEntry(string key, string value)
		{
			return ((DetailedLocalizationTable<StringTableEntry>)(object)StringTable).AddEntry(key, value);
		}
	}
	internal class MainMenuTable : CustomLocalizationTable
	{
		internal StringTableEntry Multiplayer;

		internal StringTableEntry Lobby;

		internal StringTableEntry Invite;

		internal StringTableEntry JoinLobby;

		internal StringTableEntry CreateLobby;

		internal MainMenuTable()
			: base("Main Menu")
		{
			Multiplayer = AddEntry("BonkWithFriendsMod_Multiplayer", "Multiplayer");
			Lobby = AddEntry("BonkWithFriendsMod_Lobby", "Lobby");
			Invite = AddEntry("BonkWithFriendsMod_Invite", "Invite");
			JoinLobby = AddEntry("BonkWithFriendsMod_JoinLobby", "Join lobby");
			CreateLobby = AddEntry("BonkWithFriendsMod_CreateLobby", "Create lobby");
		}
	}
}
namespace Megabonk.BonkWithFriends.IO
{
	internal sealed class NativeMemoryPool : IDisposable
	{
		internal static readonly NativeMemoryPool Shared = new NativeMemoryPool(1500, 1024);

		private readonly object _syncRoot = new object();

		private readonly int _size;

		private readonly int _amount;

		private readonly IntPtr[] _allocatedPools;

		private readonly bool[] _takenAllocatedPools;

		private bool _disposedValue;

		private NativeMemoryPool(int size, int amount)
		{
			_size = size;
			_amount = amount;
			lock (_syncRoot)
			{
				_allocatedPools = new IntPtr[_amount];
				_takenAllocatedPools = new bool[_amount];
				for (int i = 0; i < _allocatedPools.Length; i++)
				{
					IntPtr intPtr = Marshal.AllocHGlobal(_size);
					if (intPtr != IntPtr.Zero)
					{
						_allocatedPools[i] = intPtr;
					}
				}
			}
		}

		internal IntPtr Rent()
		{
			lock (_syncRoot)
			{
				for (int i = 0; i < _allocatedPools.Length; i++)
				{
				}
			}
			return IntPtr.Zero;
		}

		internal void Return(IntPtr allocatedMemoryPointer)
		{
		}

		private void FreePools()
		{
			lock (_syncRoot)
			{
				for (int i = 0; i < _allocatedPools.Length; i++)
				{
					IntPtr intPtr = _allocatedPools[i];
					if (intPtr != IntPtr.Zero)
					{
						Marshal.FreeHGlobal(intPtr);
					}
				}
			}
		}

		private void Dispose(bool disposing)
		{
			if (!_disposedValue)
			{
				if (disposing)
				{
					FreePools();
				}
				_disposedValue = true;
			}
		}

		public void Dispose()
		{
			Dispose(disposing: true);
			GC.SuppressFinalize(this);
		}
	}
	internal sealed class NetworkReader : BinaryReader
	{
		internal NetworkReader(Stream input)
			: base(input)
		{
		}

		internal NetworkReader(Stream input, Encoding encoding)
			: base(input, encoding)
		{
		}

		internal NetworkReader(Stream input, Encoding encoding, bool leaveOpen)
			: base(input, encoding, leaveOpen)
		{
		}

		internal Vector2 ReadVector2()
		{
			//IL_000c: Unknown result type (might be due to invalid IL or missing references)
			return new Vector2(ReadSingle(), ReadSingle());
		}

		internal Vector3 ReadVector3()
		{
			//IL_0012: Unknown result type (might be due to invalid IL or missing references)
			return new Vector3(ReadSingle(), ReadSingle(), ReadSingle());
		}

		internal Vector3 ReadVector3Fast()
		{
			//IL_004f: Unknown result type (might be due to invalid IL or missing references)
			Span<byte> buffer = stackalloc byte[12];
			Read(buffer);
			return new Vector3(BinaryPrimitives.ReadSingleLittleEndian(buffer.Slice(0, 4)), BinaryPrimitives.ReadSingleLittleEndian(buffer.Slice(4, 8)), BinaryPrimitives.ReadSingleLittleEndian(buffer.Slice(8, 12)));
		}

		internal Vector4 ReadVector4()
		{
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			return new Vector4(ReadSingle(), ReadSingle(), ReadSingle(), ReadSingle());
		}

		internal Quaternion ReadQuaternion()
		{
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			return new Quaternion(ReadSingle(), ReadSingle(), ReadSingle(), ReadSingle());
		}

		internal Quaternion ReadQuaternionFast()
		{
			//IL_0064: Unknown result type (might be due to invalid IL or missing references)
			Span<byte> buffer = stackalloc byte[16];
			Read(buffer);
			return new Quaternion(BinaryPrimitives.ReadSingleLittleEndian(buffer.Slice(0, 4)), BinaryPrimitives.ReadSingleLittleEndian(buffer.Slice(4, 8)), BinaryPrimitives.ReadSingleLittleEndian(buffer.Slice(8, 12)), BinaryPrimitives.ReadSingleLittleEndian(buffer.Slice(12, 16)));
		}

		internal (Quaternion rotation, Vector3 position) ReadTransform()
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_0007: Unknown result type (might be due to invalid IL or missing references)
			return (rotation: ReadQuaternion(), position: ReadVector3());
		}

		internal Ray ReadRay()
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_0007: Unknown result type (might be due to invalid IL or missing references)
			//IL_000c: Unknown result type (might be due to invalid IL or missing references)
			return new Ray(ReadVector3(), ReadVector3());
		}

		internal Rect ReadRect()
		{
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			return new Rect(ReadSingle(), ReadSingle(), ReadSingle(), ReadSingle());
		}

		internal Matrix4x4 ReadMatrix4x4()
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_0007: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0013: Unknown result type (might be due to invalid IL or missing references)
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			return new Matrix4x4(ReadVector4(), ReadVector4(), ReadVector4(), ReadVector4());
		}

		internal Color ReadColor()
		{
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			return new Color(ReadSingle(), ReadSingle(), ReadSingle(), ReadSingle());
		}

		internal Color32 ReadColor32()
		{
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			return new Color32(ReadByte(), ReadByte(), ReadByte(), ReadByte());
		}

		internal MessageType ReadMessageType()
		{
			return (MessageType)ReadUInt16();
		}
	}
	internal sealed class NetworkWriter : BinaryWriter
	{
		internal NetworkWriter(Stream output)
			: base(output)
		{
		}

		internal NetworkWriter(Stream output, Encoding encoding)
			: base(output, encoding)
		{
		}

		internal NetworkWriter(Stream output, Encoding encoding, bool leaveOpen)
			: base(output, encoding, leaveOpen)
		{
		}

		internal void WriteVector2(Vector2 vector2)
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			Write(vector2.x);
			Write(vector2.y);
		}

		internal void WriteVector3(Vector3 vector3)
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0019: Unknown result type (might be due to invalid IL or missing references)
			Write(vector3.x);
			Write(vector3.y);
			Write(vector3.z);
		}

		internal void WriteVector3Fast(Vector3 vector3)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			Span<byte> span = stackalloc byte[12];
			BinaryPrimitives.WriteSingleLittleEndian(span, vector3.x);
			BinaryPrimitives.WriteSingleLittleEndian(span, vector3.y);
			BinaryPrimitives.WriteSingleLittleEndian(span, vector3.z);
			OutStream.Write(span);
		}

		internal void WriteVector4(Vector4 vector4)
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0019: Unknown result type (might be due to invalid IL or missing references)
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			Write(vector4.x);
			Write(vector4.y);
			Write(vector4.z);
			Write(vector4.w);
		}

		internal void WriteQuaternion(Quaternion quaternion)
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0019: Unknown result type (might be due to invalid IL or missing references)
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			Write(quaternion.x);
			Write(quaternion.y);
			Write(quaternion.z);
			Write(quaternion.w);
		}

		internal void WriteQuaternionFast(Quaternion quaternion)
		{
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0026: Unknown result type (might be due to invalid IL or missing references)
			//IL_0032: Unknown result type (might be due to invalid IL or missing references)
			Span<byte> span = stackalloc byte[16];
			BinaryPrimitives.WriteSingleLittleEndian(span, quaternion.x);
			BinaryPrimitives.WriteSingleLittleEndian(span, quaternion.y);
			BinaryPrimitives.WriteSingleLittleEndian(span, quaternion.z);
			BinaryPrimitives.WriteSingleLittleEndian(span, quaternion.w);
			OutStream.Write(span);
		}

		internal void WriteTransform(Transform transform)
		{
			//IL_0002: Unknown result type (might be due to invalid IL or missing references)
			//IL_000e: Unknown result type (might be due to invalid IL or missing references)
			WriteQuaternion(transform.rotation);
			WriteVector3(transform.position);
		}

		internal void WriteRay(Ray ray)
		{
			//IL_0003: Unknown result type (might be due to invalid IL or missing references)
			//IL_0010: Unknown result type (might be due to invalid IL or missing references)
			WriteVector3(((Ray)(ref ray)).origin);
			WriteVector3(((Ray)(ref ray)).direction);
		}

		internal void WriteRect(Rect rect)
		{
			Write(((Rect)(ref rect)).x);
			Write(((Rect)(ref rect)).y);
			Write(((Rect)(ref rect)).width);
			Write(((Rect)(ref rect)).height);
		}

		internal void WriteMatrix4x4(Matrix4x4 matrix)
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0019: Unknown result type (might be due to invalid IL or missing references)
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			//IL_0031: Unknown result type (might be due to invalid IL or missing references)
			//IL_003d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0049: Unknown result type (might be due to invalid IL or missing references)
			//IL_0055: Unknown result type (might be due to invalid IL or missing references)
			//IL_0061: Unknown result type (might be due to invalid IL or missing references)
			//IL_006d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0079: Unknown result type (might be due to invalid IL or missing references)
			//IL_0085: Unknown result type (might be due to invalid IL or missing references)
			//IL_0091: Unknown result type (might be due to invalid IL or missing references)
			//IL_009d: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a9: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b5: Unknown result type (might be due to invalid IL or missing references)
			Write(matrix.m00);
			Write(matrix.m01);
			Write(matrix.m02);
			Write(matrix.m03);
			Write(matrix.m10);
			Write(matrix.m11);
			Write(matrix.m12);
			Write(matrix.m13);
			Write(matrix.m20);
			Write(matrix.m21);
			Write(matrix.m22);
			Write(matrix.m23);
			Write(matrix.m30);
			Write(matrix.m31);
			Write(matrix.m32);
			Write(matrix.m33);
		}

		internal void WriteColor(Color color)
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0019: Unknown result type (might be due to invalid IL or missing references)
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			Write(color.r);
			Write(color.g);
			Write(color.b);
			Write(color.a);
		}

		internal void WriteColor32(Color32 color32)
		{
			//IL_0001: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0019: Unknown result type (might be due to invalid IL or missing references)
			//IL_0025: Unknown result type (might be due to invalid IL or missing references)
			Write(color32.r);
			Write(color32.g);
			Write(color32.b);
			Write(color32.a);
		}

		internal void WriteMessageType(MessageType messageType)
		{
			Write((ushort)messageType);
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.Unity
{
	[HarmonyPatch]
	public static class ComponentPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch(/*Could not decode attribute arguments.*/)]
		public static bool Component_Transform_Prefix(Component __instance, ref Transform __result)
		{
			ulong playerId = 0uL;
			MatchContext current = MatchContext.Current;
			if (current == null || !current.PlayerTransformContext.TryGetCurrentContext(out playerId))
			{
				return true;
			}
			NetworkedPlayer player = MatchContext.Current.RemotePlayers.GetPlayer(new CSteamID(playerId));
			if ((Object)(object)player == (Object)null || (Object)(object)player.ModelInstance == (Object)null)
			{
				return true;
			}
			__result = player.ModelInstance.transform;
			return false;
		}
	}
	[HarmonyPatch(typeof(Object))]
	internal static class UnityObjectPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("Instantiate", new Type[]
		{
			typeof(Object),
			typeof(Vector3),
			typeof(Quaternion)
		})]
		private static bool Instantiate_Prefix(Object original)
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			if (original != (Object)null && original.name.Contains("BossSpawner"))
			{
				return false;
			}
			return true;
		}

		[HarmonyPostfix]
		[HarmonyPatch("Instantiate", new Type[]
		{
			typeof(Object),
			typeof(Vector3),
			typeof(Quaternion)
		})]
		private static void Instantiate_Postfix(Object __result, Object original)
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Server && !(__result == (Object)null) && !(original == (Object)null))
			{
				GameObject val = ((Il2CppObjectBase)original).TryCast<GameObject>();
				GameObject val2 = ((Il2CppObjectBase)__result).TryCast<GameObject>();
				if (!((Object)(object)val == (Object)null) && !((Object)(object)val2 == (Object)null))
				{
					HandleQuestObjectsSpawned(val, val2);
					HandleBossSpawnerOnProceduralMap(val, val2);
					HandleDesertGraves(val, val2);
				}
			}
		}

		private static void HandleBossSpawnerOnProceduralMap(GameObject originalGo, GameObject resultGo)
		{
			//IL_0020: Unknown result type (might be due to invalid IL or missing references)
			//IL_002d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0033: Invalid comparison between Unknown and I4
			//IL_0086: Unknown result type (might be due to invalid IL or missing references)
			//IL_0091: Unknown result type (might be due to invalid IL or missing references)
			RunConfig runConfig = MapController.runConfig;
			if (runConfig == null)
			{
				return;
			}
			MapData mapData = runConfig.mapData;
			if ((int)((mapData != null) ? new EMapType?(mapData.mapType) : ((EMapType?)null)).GetValueOrDefault() == 1 && ((Object)resultGo).name.StartsWith("BossSpawner"))
			{
				MatchContext current = MatchContext.Current;
				if (current == null || !current.SpawnedObjects.TryGetObjectId(resultGo, out var _))
				{
					MatchContext.Current?.SpawnedObjects.RegisterHostObject(resultGo, ((Object)originalGo).name, resultGo.transform.position, resultGo.transform.rotation);
				}
			}
		}

		private static void HandleQuestObjectsSpawned(GameObject originalGo, GameObject resultGo)
		{
			//IL_00ea: Unknown result type (might be due to invalid IL or missing references)
			//IL_00f5: Unknown result type (might be due to invalid IL or missing references)
			if ((Object)(object)EffectManager.Instance == (Object)null)
			{
				return;
			}
			EffectManager instance = EffectManager.Instance;
			if (!((Object)(object)originalGo != (Object)(object)instance.bananaQuest) || !((Object)(object)originalGo != (Object)(object)instance.banditQuest) || !((Object)(object)originalGo != (Object)(object)instance.boomboxQuest) || !((Object)(object)originalGo != (Object)(object)instance.bushQuest) || !((Object)(object)originalGo != (Object)(object)instance.katanaQuest) || !((Object)(object)originalGo != (Object)(object)instance.luckTomeQuest) || !((Object)(object)originalGo != (Object)(object)instance.shotgunQuest) || !((Object)(object)originalGo != (Object)(object)instance.presentQuest) || !((Object)(object)originalGo != (Object)(object)instance.frogQuest1) || !((Object)(object)originalGo != (Object)(object)instance.frogQuest2) || !((Object)(object)originalGo != (Object)(object)instance.frogQuest3))
			{
				MatchContext current = MatchContext.Current;
				if (current == null || !current.SpawnedObjects.TryGetObjectId(resultGo, out var _))
				{
					MatchContext.Current?.SpawnedObjects.RegisterHostObject(resultGo, ((Object)originalGo).name, resultGo.transform.position, resultGo.transform.rotation);
				}
			}
		}

		private static void HandleDesertGraves(GameObject originalGo, GameObject resultGo)
		{
			//IL_0075: Unknown result type (might be due to invalid IL or missing references)
			//IL_0080: Unknown result type (might be due to invalid IL or missing references)
			if ((Object)(object)EffectManager.Instance == (Object)null)
			{
				return;
			}
			MatchContext current = MatchContext.Current;
			if (current != null && current.SpawnedObjects.CanSendNetworkMessages && ((Il2CppArrayBase<GameObject>)(object)EffectManager.Instance.desertGraves).Contains(originalGo))
			{
				MatchContext current2 = MatchContext.Current;
				if (current2 == null || !current2.SpawnedObjects.TryGetObjectId(resultGo, out var _))
				{
					MatchContext.Current?.SpawnedObjects.RegisterHostObject(resultGo, ((Object)originalGo).name, resultGo.transform.position, resultGo.transform.rotation);
				}
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch("Destroy", new Type[] { typeof(Object) })]
		private static void Destroy_Prefix(Object obj)
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined || obj == (Object)null)
			{
				return;
			}
			GameObject val = ((Il2CppObjectBase)obj).TryCast<GameObject>();
			if ((Object)(object)val == (Object)null)
			{
				return;
			}
			MatchContext current = MatchContext.Current;
			if (current != null && current.FinalBossOrbs.ContainsOrb(val))
			{
				ulong? num = MatchContext.Current?.FinalBossOrbs.RemoveOrb(val);
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server && num.HasValue)
				{
					FinalBossOrbDestroyedMessage tMsg = new FinalBossOrbDestroyedMessage
					{
						OrbId = (uint)num.Value
					};
					SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
				}
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.UI
{
	[HarmonyPatch(typeof(ChestOpening))]
	internal static class ChestOpeningPatches
	{
		[HarmonyPostfix]
		[HarmonyPatch("OpenChest")]
		private static void OpenChest_Postfix(ChestOpening __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				__instance.skipped = true;
			}
		}
	}
	[HarmonyPatch(typeof(ChestWindowUi))]
	internal static class ChestWindowUiPatches
	{
		private static TextMeshProUGUI _countdownText;

		private static MyButton _cachedOpenButton;

		[HarmonyPostfix]
		[HarmonyPatch("Open")]
		private static void Open_Postfix(ChestWindowUi __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				if ((Object)(object)_cachedOpenButton == (Object)null)
				{
					_cachedOpenButton = __instance.b_open;
				}
				__instance.OpenButton();
				__instance.b_open = null;
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch("OpeningFinished")]
		private static void OpeningFinished_Postfix(ChestWindowUi __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && GameManager.Instance.player.playerInput.CanInput())
			{
				MyTime.Unpause();
				CoroutineRunner.Start(InvincibilityCountdown(__instance, 8f));
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch("OnClose")]
		private static void OnClose_Postfix(ChestWindowUi __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				__instance.b_open = _cachedOpenButton;
				CoroutineRunner.Start(InvincibilityCountdown(__instance, 1f));
			}
		}

		private static IEnumerator InvincibilityCountdown(ChestWindowUi chest, float duration)
		{
			if ((Object)(object)_countdownText == (Object)null)
			{
				GameObject val = new GameObject("ChestInvincibilityCountdown");
				Object.DontDestroyOnLoad((Object)val);
				_countdownText = val.AddComponent<TextMeshProUGUI>();
				((TMP_Text)_countdownText).alignment = (TextAlignmentOptions)514;
				((TMP_Text)_countdownText).fontSize = 24f;
				((Graphic)_countdownText).color = Color.white;
			}
			MyPlayer player = GameManager.Instance.player;
			player.isTeleporting = true;
			((Behaviour)_countdownText).enabled = true;
			((TMP_Text)_countdownText).transform.SetParent(((Component)chest).transform);
			RectTransform rectTransform = ((TMP_Text)_countdownText).rectTransform;
			rectTransform.anchorMin = new Vector2(0f, 0f);
			rectTransform.anchorMax = new Vector2(0f, 0f);
			rectTransform.pivot = new Vector2(0f, 0f);
			rectTransform.anchoredPosition = new Vector2(100f, 100f);
			for (float timeRemaining = duration; timeRemaining > 0f; timeRemaining -= Time.deltaTime)
			{
				int num = Mathf.FloorToInt(timeRemaining);
				int value = Mathf.FloorToInt((timeRemaining - (float)num) * 1000f);
				((TMP_Text)_countdownText).text = $"You will be vulnerable in {num:D2}:{value:D3}s";
				yield return null;
			}
			player.isTeleporting = false;
			if (duration > 2f)
			{
				((TMP_Text)_countdownText).text = "You are now vulnerable!";
				((Graphic)_countdownText).color = Color.red;
				yield return (object)new WaitForSeconds(1f);
				((Graphic)_countdownText).color = Color.white;
			}
			((Behaviour)_countdownText).enabled = false;
		}
	}
	[HarmonyPatch(typeof(EncounterUi))]
	internal static class EncounterUiPatches
	{
		private static TextMeshProUGUI _countdownText;

		[HarmonyPostfix]
		[HarmonyPatch("Open")]
		private static void Open_Postfix()
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && GameManager.Instance.player.playerInput.CanInput())
			{
				MyTime.Unpause();
				CoroutineRunner.Start(InvincibilityCountdown(8f, "You will be vulnerable in"));
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch("OnClose")]
		private static void OnClose_Postfix()
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				CoroutineRunner.Start(InvincibilityCountdown(1f, "Grace period"));
			}
		}

		private static IEnumerator InvincibilityCountdown(float duration, string messagePrefix)
		{
			if ((Object)(object)_countdownText == (Object)null)
			{
				GameObject val = new GameObject("InvincibilityCountdown");
				Object.DontDestroyOnLoad((Object)val);
				_countdownText = val.AddComponent<TextMeshProUGUI>();
				((TMP_Text)_countdownText).alignment = (TextAlignmentOptions)514;
				((TMP_Text)_countdownText).fontSize = 24f;
				((Graphic)_countdownText).color = Color.white;
			}
			MyPlayer player = GameManager.Instance.player;
			player.isTeleporting = true;
			((Behaviour)_countdownText).enabled = true;
			((TMP_Text)_countdownText).transform.SetParent(((Component)UiManager.Instance.encounterWindows).transform);
			RectTransform rectTransform = ((TMP_Text)_countdownText).rectTransform;
			rectTransform.anchorMin = new Vector2(0f, 0f);
			rectTransform.anchorMax = new Vector2(0f, 0f);
			rectTransform.pivot = new Vector2(0f, 0f);
			rectTransform.anchoredPosition = new Vector2(100f, 100f);
			for (float timeRemaining = duration; timeRemaining > 0f; timeRemaining -= Time.deltaTime)
			{
				int num = Mathf.FloorToInt(timeRemaining);
				int value = Mathf.FloorToInt((timeRemaining - (float)num) * 1000f);
				((TMP_Text)_countdownText).text = $"{messagePrefix} {num:D2}:{value:D3}s";
				yield return null;
			}
			player.isTeleporting = false;
			((Behaviour)_countdownText).enabled = false;
			((TMP_Text)_countdownText).text = "You are now vulnerable!";
			((Graphic)_countdownText).color = Color.red;
			((Behaviour)_countdownText).enabled = true;
			yield return (object)new WaitForSeconds(1f);
			((Behaviour)_countdownText).enabled = false;
			((Graphic)_countdownText).color = Color.white;
		}
	}
	[HarmonyPatch(typeof(EncounterWindows))]
	internal static class EncounterWindowPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("AddEncounter")]
		public static bool AddEncounter_Prefix(EncounterWindows __instance, EEncounter rewardWindowType)
		{
			//IL_0017: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (__instance.encounterInProgress)
			{
				__instance.rewardQueue.Enqueue(rewardWindowType);
				return false;
			}
			return true;
		}

		[HarmonyPrefix]
		[HarmonyPatch("PopReward")]
		private static bool PopReward_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (!GameManager.Instance.player.playerInput.CanInput())
			{
				return false;
			}
			return true;
		}

		[HarmonyPostfix]
		[HarmonyPatch("PopReward")]
		private static void PopReward_Postfix()
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				MyTime.Unpause();
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch("LateUpdate")]
		private static void LateUpdate_Prefix(EncounterWindows __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && GameManager.Instance.player.playerInput.CanInput() && !GameManager.Instance.player.IsDead() && __instance.rewardQueue.Count > 0 && !__instance.encounterInProgress)
			{
				__instance.PopReward();
			}
		}
	}
	[HarmonyPatch(typeof(LevelupScreen))]
	internal static class LevelUpScreenPatches
	{
		private static TextMeshProUGUI _countdownText;

		[HarmonyPostfix]
		[HarmonyPatch("ShowLevelupScreen")]
		private static void ShowLevelupScreen_Postfix(LevelupScreen __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && GameManager.Instance.player.playerInput.CanInput())
			{
				if ((Object)(object)InteractableShadyGuy.currentlyInteracting != (Object)null)
				{
					DisplayShadyGuyWarning(__instance);
					return;
				}
				MyTime.Unpause();
				CoroutineRunner.Start(InvincibilityCountdown(__instance, 8f));
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch("OnClose")]
		private static void OnClose_Postfix(LevelupScreen __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				if ((Object)(object)InteractableShadyGuy.currentlyInteracting != (Object)null)
				{
					ClearShadyGuyWarning();
				}
				else
				{
					CoroutineRunner.Start(InvincibilityCountdown(__instance, 1f));
				}
			}
		}

		private static IEnumerator InvincibilityCountdown(LevelupScreen screen, float duration)
		{
			if ((Object)(object)_countdownText == (Object)null)
			{
				GameObject val = new GameObject("LevelUpInvincibilityCountdown");
				Object.DontDestroyOnLoad((Object)val);
				_countdownText = val.AddComponent<TextMeshProUGUI>();
				((TMP_Text)_countdownText).alignment = (TextAlignmentOptions)514;
				((TMP_Text)_countdownText).fontSize = 24f;
				((Graphic)_countdownText).color = Color.white;
			}
			MyPlayer player = GameManager.Instance.player;
			player.isTeleporting = true;
			((Behaviour)_countdownText).enabled = true;
			((TMP_Text)_countdownText).transform.SetParent(((Component)screen).transform);
			RectTransform rectTransform = ((TMP_Text)_countdownText).rectTransform;
			rectTransform.anchorMin = new Vector2(0f, 0f);
			rectTransform.anchorMax = new Vector2(0f, 0f);
			rectTransform.pivot = new Vector2(0f, 0f);
			rectTransform.anchoredPosition = new Vector2(100f, 100f);
			for (float timeRemaining = duration; timeRemaining > 0f; timeRemaining -= Time.deltaTime)
			{
				int num = Mathf.FloorToInt(timeRemaining);
				int value = Mathf.FloorToInt((timeRemaining - (float)num) * 1000f);
				((TMP_Text)_countdownText).text = $"You will be vulnerable in {num:D2}:{value:D3}s";
				yield return null;
			}
			player.isTeleporting = false;
			if (duration > 2f)
			{
				((TMP_Text)_countdownText).text = "You are now vulnerable!";
				((Graphic)_countdownText).color = Color.red;
				yield return (object)new WaitForSeconds(1f);
				((Graphic)_countdownText).color = Color.white;
			}
			((Behaviour)_countdownText).enabled = false;
		}

		private static void DisplayShadyGuyWarning(LevelupScreen screen)
		{
			//IL_005c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0071: Unknown result type (might be due to invalid IL or missing references)
			//IL_0086: Unknown result type (might be due to invalid IL or missing references)
			//IL_009a: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c7: Unknown result type (might be due to invalid IL or missing references)
			//IL_0012: Unknown result type (might be due to invalid IL or missing references)
			//IL_0017: Unknown result type (might be due to invalid IL or missing references)
			//IL_001d: Expected O, but got Unknown
			if ((Object)(object)_countdownText == (Object)null)
			{
				GameObject val = new GameObject("LevelUpInvincibilityCountdown");
				Object.DontDestroyOnLoad((Object)val);
				_countdownText = val.AddComponent<TextMeshProUGUI>();
			}
			((Behaviour)_countdownText).enabled = true;
			((TMP_Text)_countdownText).transform.SetParent(((Component)screen).transform);
			RectTransform rectTransform = ((TMP_Text)_countdownText).rectTransform;
			rectTransform.anchorMin = new Vector2(0f, 0f);
			rectTransform.anchorMax = new Vector2(0f, 0f);
			rectTransform.pivot = new Vector2(0f, 0f);
			rectTransform.anchoredPosition = new Vector2(100f, 100f);
			((TMP_Text)_countdownText).alignment = (TextAlignmentOptions)514;
			((TMP_Text)_countdownText).fontSize = 36f;
			((Graphic)_countdownText).color = Color.red;
			((TMP_Text)_countdownText).text = "You are vulnerable during shady guy interaction!";
		}

		private static void ClearShadyGuyWarning()
		{
			//IL_002c: Unknown result type (might be due to invalid IL or missing references)
			if ((Object)(object)_countdownText != (Object)null)
			{
				((Behaviour)_countdownText).enabled = false;
				((TMP_Text)_countdownText).text = "";
				((Graphic)_countdownText).color = Color.white;
			}
			InteractableShadyGuy.currentlyInteracting = null;
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.Spawning
{
	[HarmonyPatch]
	internal static class SummonerPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch(typeof(SummonerController), "Tick")]
		private static bool BlockClientTick()
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined)
			{
				return SteamNetworkManager.Mode == SteamNetworkMode.Server;
			}
			return true;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SummonerController), "TickTimeline")]
		private static bool BlockClientTimeline()
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined)
			{
				return SteamNetworkManager.Mode == SteamNetworkMode.Server;
			}
			return true;
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(SummonerController), "TickTimeline")]
		private static void OnTimelineAdvanced(SummonerController __instance)
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				int currentTimelineEvent = __instance.currentTimelineEvent;
				if (currentTimelineEvent >= 0)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(new TimelineEventMessage
					{
						EventIndex = currentTimelineEvent,
						HostTime = Time.time
					});
				}
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SummonerController), "TryAddNewEnemyCard")]
		private static bool BlockClientAddCard()
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined)
			{
				return SteamNetworkManager.Mode == SteamNetworkMode.Server;
			}
			return true;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SummonerController), "CanAddNewEnemyCard")]
		private static bool BlockClientCanAddCard(ref bool __result)
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined || SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			__result = false;
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SummonerController), "StartEvent")]
		private static void OnTimelineEvent(int eventIndex)
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(new TimelineEventMessage
				{
					EventIndex = eventIndex,
					HostTime = Time.time
				});
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SummonerController), "EventSwarm")]
		private static void OnSwarmEvent(TimelineEvent timelineEvent)
		{
			//IL_0023: Unknown result type (might be due to invalid IL or missing references)
			//IL_002d: Expected I4, but got Unknown
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(new WaveCueMessage
				{
					WaveType = (int)timelineEvent.eTimelineEvent,
					Duration = timelineEvent.duration
				});
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SummonerController), "StartFinalSwarm")]
		private static void OnFinalSwarm()
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(new WaveFinalCueMessage());
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(SummonerController), "SpawnStageBoss")]
		private static void OnBossSpawned(List<Enemy> __result, Vector3 pos)
		{
			//IL_0056: Unknown result type (might be due to invalid IL or missing references)
			//IL_005b: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Server && __result != null && __result.Count != 0)
			{
				BossSpawnSyncMessage bossSpawnSyncMessage = new BossSpawnSyncMessage();
				Enumerator<Enemy> enumerator = __result.GetEnumerator();
				while (enumerator.MoveNext())
				{
					Enemy current = enumerator.Current;
					bossSpawnSyncMessage.Spawns.Add(new BossSpawnSyncMessage.BossInfo
					{
						BossPartId = current.id,
						Position = ((Component)current).transform.position,
						MaxHp = current.maxHp
					});
				}
				SteamNetworkServer.Instance?.BroadcastMessage(bossSpawnSyncMessage);
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SummonerController), "OnBossDied")]
		private static void OnBossDied(bool isLastStage)
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(new BossDiedMessage
				{
					IsLastStage = isLastStage,
					HostTime = Time.time
				});
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SummonerController), "TryStopSummoners")]
		private static void OnSpawningStop()
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(new WavesStoppedMessage());
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.Player
{
	[HarmonyPatch(typeof(PlayerCamera))]
	public static class PlayerCameraPatches
	{
		private static SpectatorCamera _spectatorCamera;

		private static SpectatorCamera GetSpectatorCamera()
		{
			//IL_002f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0034: Unknown result type (might be due to invalid IL or missing references)
			//IL_003a: Expected O, but got Unknown
			if ((Object)(object)_spectatorCamera != (Object)null)
			{
				return _spectatorCamera;
			}
			_spectatorCamera = Object.FindObjectOfType<SpectatorCamera>();
			if ((Object)(object)_spectatorCamera == (Object)null)
			{
				GameObject val = new GameObject("SpectatorCamera");
				Object.DontDestroyOnLoad((Object)val);
				_spectatorCamera = val.AddComponent<SpectatorCamera>();
			}
			return _spectatorCamera;
		}

		[HarmonyPrefix]
		[HarmonyPatch("CameraInput")]
		public static bool CameraInput_Prefix(PlayerCamera __instance, Vector3 playerRotation)
		{
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			SpectatorCamera spectatorCamera = GetSpectatorCamera();
			if ((Object)(object)spectatorCamera != (Object)null && spectatorCamera.IsFollowingTarget)
			{
				spectatorCamera.UpdateFromPlayerRotation(playerRotation);
				return false;
			}
			return true;
		}

		public static void ActivateSpectatorMode()
		{
			SpectatorCamera spectatorCamera = GetSpectatorCamera();
			if ((Object)(object)spectatorCamera != (Object)null)
			{
				spectatorCamera.ActivateSpectatorMode();
			}
		}

		public static void DeactivateSpectatorMode()
		{
			SpectatorCamera spectatorCamera = GetSpectatorCamera();
			if ((Object)(object)spectatorCamera != (Object)null)
			{
				spectatorCamera.ResetToLocalPlayer();
			}
		}
	}
	[HarmonyPatch(typeof(PlayerHealth))]
	public static class PlayerHealthPatches
	{
		[HarmonyPostfix]
		[HarmonyPatch("PlayerDied")]
		public static void PlayerDied_Postfix(PlayerHealth __instance)
		{
			//IL_0040: Unknown result type (might be due to invalid IL or missing references)
			//IL_0045: Unknown result type (might be due to invalid IL or missing references)
			//IL_0080: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b1: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return;
			}
			GameManager instance = GameManager.Instance;
			MyPlayer val = ((instance != null) ? instance.player : null);
			if ((Object)(object)val == (Object)null)
			{
				ModLogger.Error("[PlayerHealthPatches] Local player not found in PlayerDied!");
				return;
			}
			CSteamID steamID = SteamUser.GetSteamID();
			string personaName = SteamFriends.GetPersonaName();
			Vector3 position = ((Component)val).transform.position;
			MatchContext.Current?.LocalPlayer.UpdatePlayerDeath(isDead: true);
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				SteamNetworkClient.Instance?.SendMessage(new PlayerDiedMessage
				{
					SteamUserId = steamID.m_SteamID,
					DeathPosition = position,
					PlayerName = personaName
				});
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				MatchContext.Current?.ReviveShrines.OnPlayerDied(steamID.m_SteamID, personaName, position);
			}
		}
	}
	[HarmonyPatch]
	public static class PlayerPatches
	{
		private static bool _isAddingXpFromNetwork;

		[HarmonyPrefix]
		[HarmonyPatch(typeof(MyPlayer), "GetFeetPosition")]
		public static bool GetFeetPosition_Prefix(ref Vector3 __result)
		{
			//IL_0050: Unknown result type (might be due to invalid IL or missing references)
			//IL_0055: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			MatchContext current = MatchContext.Current;
			if (current != null && current.RemotePlayers.TryGetProjectileSpawnContext(out var steamId))
			{
				NetworkedPlayer networkedPlayer = MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(steamId));
				if ((Object)(object)networkedPlayer != (Object)null)
				{
					__result = ((Component)networkedPlayer).transform.position;
					return false;
				}
			}
			return true;
		}

		internal static void SetAddingXpFromNetwork(bool value)
		{
			_isAddingXpFromNetwork = value;
		}

		public static void PlayerXp_AddXp_Postfix(int amount)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && Preferences.LevelSync.Value && !_isAddingXpFromNetwork)
			{
				XpGainedMessage tMsg = new XpGainedMessage
				{
					XpAmount = amount
				};
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance?.SendMessage(tMsg);
				}
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.Map
{
	[HarmonyPatch(typeof(GenerateTileObjects))]
	public static class GenerateTileObjectsPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("Generate")]
		public static bool Generate_Prefix(GenerateTileObjects __instance, StageData stageData)
		{
			//IL_0119: Unknown result type (might be due to invalid IL or missing references)
			//IL_011f: Invalid comparison between Unknown and I4
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			if (((stageData != null) ? stageData.stageTilePrefabs : null) != null)
			{
				foreach (GameObject item in (Il2CppArrayBase<GameObject>)(object)stageData.stageTilePrefabs.flatTilePrefabs)
				{
					if (Object.op_Implicit((Object)(object)item))
					{
						MatchContext.Current?.SpawnedObjects.AddPrefab(item);
					}
				}
				foreach (GameObject item2 in (Il2CppArrayBase<GameObject>)(object)stageData.stageTilePrefabs.mapSpecificTilesPrefabs)
				{
					if (Object.op_Implicit((Object)(object)item2))
					{
						MatchContext.Current?.SpawnedObjects.AddPrefab(item2);
					}
				}
			}
			if (Object.op_Implicit((Object)(object)__instance.bossSpawner))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(__instance.bossSpawner);
			}
			if (Object.op_Implicit((Object)(object)__instance.bossSpawnerFinal))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(__instance.bossSpawnerFinal);
			}
			MapData currentMap = MapController.currentMap;
			if (currentMap != null && (int)currentMap.eMap == 8 && Object.op_Implicit((Object)(object)__instance.graveyardBossPortal))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(__instance.graveyardBossPortal);
			}
			return false;
		}

		[HarmonyPostfix]
		[HarmonyPatch("Generate")]
		public static void Generate_Postfix(GenerateTileObjects __instance, StageData stageData)
		{
			//IL_00fc: Unknown result type (might be due to invalid IL or missing references)
			//IL_0102: Invalid comparison between Unknown and I4
			//IL_01bf: Unknown result type (might be due to invalid IL or missing references)
			//IL_01cb: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined || SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			HashSet<string> hashSet = new HashSet<string>();
			if (((stageData != null) ? stageData.stageTilePrefabs : null) != null)
			{
				foreach (GameObject item in (Il2CppArrayBase<GameObject>)(object)stageData.stageTilePrefabs.flatTilePrefabs)
				{
					if (Object.op_Implicit((Object)(object)item))
					{
						hashSet.Add(((Object)item).name);
					}
				}
				foreach (GameObject item2 in (Il2CppArrayBase<GameObject>)(object)stageData.stageTilePrefabs.mapSpecificTilesPrefabs)
				{
					if (Object.op_Implicit((Object)(object)item2))
					{
						hashSet.Add(((Object)item2).name);
					}
				}
			}
			if (Object.op_Implicit((Object)(object)__instance.bossSpawner))
			{
				hashSet.Add(((Object)__instance.bossSpawner).name);
			}
			if (Object.op_Implicit((Object)(object)__instance.bossSpawnerFinal))
			{
				hashSet.Add(((Object)__instance.bossSpawnerFinal).name);
			}
			MapData currentMap = MapController.currentMap;
			if (currentMap != null && (int)currentMap.eMap == 8 && Object.op_Implicit((Object)(object)__instance.graveyardBossPortal))
			{
				hashSet.Add(((Object)__instance.graveyardBossPortal).name);
			}
			if (hashSet.Count == 0)
			{
				return;
			}
			Il2CppArrayBase<GameObject> obj = Object.FindObjectsOfType<GameObject>();
			int num = 0;
			foreach (GameObject item3 in obj)
			{
				if (!Object.op_Implicit((Object)(object)item3) || string.IsNullOrEmpty(((Object)item3).name))
				{
					continue;
				}
				MatchContext current4 = MatchContext.Current;
				if (current4 != null && current4.SpawnedObjects.TryGetObjectId(item3, out var _))
				{
					continue;
				}
				foreach (string item4 in hashSet)
				{
					if (((Object)item3).name.StartsWith(item4))
					{
						MatchContext.Current?.SpawnedObjects.RegisterHostObject(item3, item4, item3.transform.position, item3.transform.rotation);
						num++;
						break;
					}
				}
			}
		}
	}
	[HarmonyPatch(typeof(_GenerateMap_d__39))]
	public static class MapGenerationPrefabRegistration
	{
		[HarmonyPrefix]
		[HarmonyPatch(typeof(_GenerateMap_d__39), "MoveNext")]
		private static void MoveNext_Prefix(_GenerateMap_d__39 __instance)
		{
			//IL_0354: Unknown result type (might be due to invalid IL or missing references)
			//IL_035a: Invalid comparison between Unknown and I4
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined || SteamNetworkManager.Mode == SteamNetworkMode.Server || (Object)(object)__instance._stageData_5__3 == (Object)null)
			{
				return;
			}
			int num = 0;
			foreach (RandomMapObject item in (Il2CppArrayBase<RandomMapObject>)(object)__instance.__4__this.randomObjectPlacer.randomObjects)
			{
				foreach (GameObject item2 in (Il2CppArrayBase<GameObject>)(object)item.prefabs)
				{
					if (Object.op_Implicit((Object)(object)item2))
					{
						MatchContext.Current?.SpawnedObjects.AddPrefab(item2);
						num++;
					}
				}
			}
			foreach (RandomMapObject item3 in (Il2CppArrayBase<RandomMapObject>)(object)__instance._stageData_5__3.randomMapObjects)
			{
				if (((item3 != null) ? item3.prefabs : null) == null)
				{
					continue;
				}
				foreach (GameObject item4 in (Il2CppArrayBase<GameObject>)(object)item3.prefabs)
				{
					if (Object.op_Implicit((Object)(object)item4))
					{
						MatchContext.Current?.SpawnedObjects.AddPrefab(item4);
						num++;
					}
				}
			}
			foreach (GameObject item5 in (Il2CppArrayBase<GameObject>)(object)__instance.__4__this.randomObjectPlacer.greedShrineSpawns.prefabs)
			{
				if (Object.op_Implicit((Object)(object)item5))
				{
					MatchContext.Current?.SpawnedObjects.AddPrefab(item5);
					num++;
				}
			}
			foreach (GameObject item6 in (Il2CppArrayBase<GameObject>)(object)__instance.__4__this.randomObjectPlacer.chargeShrineSpawns.prefabs)
			{
				if (Object.op_Implicit((Object)(object)item6))
				{
					MatchContext.Current?.SpawnedObjects.AddPrefab(item6);
					num++;
				}
			}
			foreach (GameObject item7 in (Il2CppArrayBase<GameObject>)(object)__instance._mapData_5__4.shrines)
			{
				if (Object.op_Implicit((Object)(object)item7))
				{
					MatchContext.Current?.SpawnedObjects.AddPrefab(item7);
					num++;
				}
			}
			foreach (RandomMapObject item8 in (Il2CppArrayBase<RandomMapObject>)(object)__instance._mapData_5__4.randomObjectsOverride)
			{
				if (((item8 != null) ? item8.prefabs : null) == null)
				{
					continue;
				}
				foreach (GameObject item9 in (Il2CppArrayBase<GameObject>)(object)item8.prefabs)
				{
					if (Object.op_Implicit((Object)(object)item9) && !((Object)item9).name.Contains("Microwave"))
					{
						MatchContext.Current?.SpawnedObjects.AddPrefab(item9);
						num++;
					}
				}
			}
			MatchContext.Current?.SpawnedObjects.AddPrefab(EffectManager.Instance.frogQuest1);
			num++;
			MatchContext.Current?.SpawnedObjects.AddPrefab(EffectManager.Instance.frogQuest2);
			num++;
			MatchContext.Current?.SpawnedObjects.AddPrefab(EffectManager.Instance.frogQuest3);
			num++;
			MapData mapData_5__ = __instance._mapData_5__4;
			if (mapData_5__ != null && (int)mapData_5__.mapType == 1)
			{
				MapGenerationController _4__this = __instance.__4__this;
				if (Object.op_Implicit((Object)(object)((_4__this != null) ? _4__this.bossPortal : null)))
				{
					MatchContext.Current?.SpawnedObjects.AddPrefab(__instance.__4__this.bossPortal);
					num++;
				}
				MapGenerationController _4__this2 = __instance.__4__this;
				if (Object.op_Implicit((Object)(object)((_4__this2 != null) ? _4__this2.bossPortalFinal : null)))
				{
					MatchContext.Current?.SpawnedObjects.AddPrefab(__instance.__4__this.bossPortalFinal);
					num++;
				}
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.Items
{
	[HarmonyPatch(typeof(ChargeShrine))]
	public static class ChargeShrinePatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("OnTriggerEnter")]
		private static bool OnTriggerEnter_Prefix(DetectInteractables __instance)
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined)
			{
				return true;
			}
			MatchContext current = MatchContext.Current;
			if (current == null || !current.SpawnedObjects.CanSendNetworkMessages)
			{
				return true;
			}
			int id = 0;
			MatchContext current2 = MatchContext.Current;
			if (current2 == null || !current2.SpawnedObjects.TryGetObjectId(((Component)__instance).gameObject, out id))
			{
				return true;
			}
			ulong steamID = SteamUser.GetSteamID().m_SteamID;
			StartChargingShrineMessage tMsg = new StartChargingShrineMessage
			{
				ShrineObjectId = id,
				PlayerSteamId = steamID
			};
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				bool result = ChargeShrineState.AddCharger(id, steamID);
				SteamNetworkServer instance = SteamNetworkServer.Instance;
				if (instance != null)
				{
					instance.BroadcastMessage(tMsg);
					return result;
				}
				return result;
			}
			SteamNetworkClient.Instance?.SendMessage(tMsg);
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch("OnTriggerExit")]
		public static bool OnTriggerExit_Prefix(ChargeShrine __instance)
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined)
			{
				return true;
			}
			MatchContext current = MatchContext.Current;
			if (current == null || !current.SpawnedObjects.CanSendNetworkMessages)
			{
				return true;
			}
			int id = 0;
			MatchContext current2 = MatchContext.Current;
			if (current2 == null || !current2.SpawnedObjects.TryGetObjectId(((Component)__instance).gameObject, out id))
			{
				return true;
			}
			ulong steamID = SteamUser.GetSteamID().m_SteamID;
			StopChargingShrineMessage tMsg = new StopChargingShrineMessage
			{
				ShrineObjectId = id,
				PlayerSteamId = steamID
			};
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				bool result = ChargeShrineState.RemoveCharger(id, steamID);
				SteamNetworkServer instance = SteamNetworkServer.Instance;
				if (instance != null)
				{
					instance.BroadcastMessage(tMsg);
					return result;
				}
				return result;
			}
			SteamNetworkClient.Instance?.SendMessage(tMsg);
			return false;
		}
	}
	[HarmonyPatch(typeof(DetectInteractables))]
	public static class DetectInteractablesPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("TryInteract")]
		private static bool TryInteract_Prefix(DetectInteractables __instance)
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined)
			{
				return true;
			}
			MatchContext current = MatchContext.Current;
			if (current == null || !current.SpawnedObjects.CanSendNetworkMessages)
			{
				return true;
			}
			BaseInteractable currentInteractable = __instance.currentInteractable;
			if (!Object.op_Implicit((Object)(object)currentInteractable))
			{
				return true;
			}
			GameObject gameObject = ((Component)currentInteractable).gameObject;
			if (!ShouldSynchronizeInteraction(currentInteractable, gameObject))
			{
				return true;
			}
			BroadcastInteraction(gameObject);
			return true;
		}

		private static bool ShouldSynchronizeInteraction(BaseInteractable interactable, GameObject go)
		{
			MatchContext current = MatchContext.Current;
			if (current == null || !current.SpawnedObjects.TryGetObjectId(go, out var _))
			{
				return false;
			}
			InteractableChest val = ((Il2CppObjectBase)interactable).TryCast<InteractableChest>();
			if (Object.op_Implicit((Object)(object)val))
			{
				if (!val.CanAfford())
				{
					return false;
				}
				return true;
			}
			if (Object.op_Implicit((Object)(object)((Il2CppObjectBase)interactable).TryCast<InteractablePortal>()))
			{
				GameManager instance = GameManager.Instance;
				if (instance != null)
				{
					MyPlayer player = instance.player;
					if (((player != null) ? new bool?(player.isTeleporting) : ((bool?)null)) == true)
					{
						return false;
					}
				}
				return true;
			}
			if (!interactable.CanInteract())
			{
				return false;
			}
			return true;
		}

		private static void BroadcastInteraction(GameObject interactableGO)
		{
			ulong steamID = SteamUser.GetSteamID().m_SteamID;
			MatchContext.Current?.SpawnedObjects.BroadcastObjectUsed(interactableGO, steamID);
		}
	}
	[HarmonyPatch(typeof(EffectManager))]
	internal static class EffectManagerPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("OnMapGenerationComplete")]
		private static bool OnMapGenerationComplete_Prefix()
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			EffectManager instance = EffectManager.Instance;
			if ((Object)(object)instance == (Object)null)
			{
				return true;
			}
			if (Object.op_Implicit((Object)(object)instance.bananaQuest))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(instance.bananaQuest);
			}
			if (Object.op_Implicit((Object)(object)instance.banditQuest))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(instance.banditQuest);
			}
			if (Object.op_Implicit((Object)(object)instance.boomboxQuest))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(instance.boomboxQuest);
			}
			if (Object.op_Implicit((Object)(object)instance.bushQuest))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(instance.bushQuest);
			}
			if (Object.op_Implicit((Object)(object)instance.katanaQuest))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(instance.katanaQuest);
			}
			if (Object.op_Implicit((Object)(object)instance.luckTomeQuest))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(instance.luckTomeQuest);
			}
			if (Object.op_Implicit((Object)(object)instance.shotgunQuest))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(instance.shotgunQuest);
			}
			if (Object.op_Implicit((Object)(object)instance.presentQuest))
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(instance.presentQuest);
			}
			foreach (GameObject item in (Il2CppArrayBase<GameObject>)(object)instance.desertGraves)
			{
				if (Object.op_Implicit((Object)(object)item))
				{
					MatchContext.Current?.SpawnedObjects.AddPrefab(item);
				}
			}
			return false;
		}
	}
	[HarmonyPatch]
	public static class InteractablePatches
	{
		[HarmonyPrefix]
		[HarmonyPatch(typeof(SpawnInteractables), "SpawnChests")]
		public static bool SpawnChests_Prefix(SpawnInteractables __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				MatchContext.Current?.SpawnedObjects.AddPrefab(__instance.chest);
				MatchContext.Current?.SpawnedObjects.AddPrefab(__instance.chestFree);
				return false;
			}
			return ShouldAllowSpawn("Chests");
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SpawnInteractables), "SpawnShrines")]
		private static bool SpawnShrines_Prefix()
		{
			return ShouldAllowSpawn("Shrines");
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SpawnInteractables), "SpawnShit")]
		private static bool SpawnPots_Prefix()
		{
			return ShouldAllowSpawn("Pots");
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(SpawnInteractables), "SpawnOther")]
		private static bool SpawnOther_Prefix()
		{
			return ShouldAllowSpawn("Other");
		}

		private static bool ShouldAllowSpawn(string spawnType)
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(SpawnInteractables), "SpawnChests")]
		private static void SpawnChests_Postfix(SpawnInteractables __instance)
		{
			//IL_005a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0065: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			foreach (InteractableChest item in Object.FindObjectsOfType<InteractableChest>())
			{
				GameObject gameObject = ((Component)item).gameObject;
				MatchContext current = MatchContext.Current;
				if (current == null || !current.SpawnedObjects.TryGetObjectId(gameObject, out var _))
				{
					MatchContext.Current?.SpawnedObjects.RegisterHostObject(gameObject, ((Object)gameObject).name, gameObject.transform.position, gameObject.transform.rotation);
				}
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(SpawnInteractables), "SpawnShrines")]
		private static void SpawnShrines_Postfix(SpawnInteractables __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				RegisterAllShrines();
			}
		}

		private static void RegisterAllShrines()
		{
			//IL_00dd: Unknown result type (might be due to invalid IL or missing references)
			//IL_00e9: Unknown result type (might be due to invalid IL or missing references)
			MapData currentMap = MapController.currentMap;
			List<GameObject> list = new List<GameObject>();
			foreach (GameObject item in (Il2CppArrayBase<GameObject>)(object)currentMap.shrines)
			{
				if (!((Object)(object)item == (Object)null) && !((Object)(object)item.GetComponentInChildren<InteractableShadyGuy>() != (Object)null) && !((Object)(object)item.GetComponentInChildren<InteractableMicrowave>() != (Object)null))
				{
					list.Add(item);
				}
			}
			Il2CppArrayBase<GameObject> obj = Object.FindObjectsOfType<GameObject>();
			int num = 0;
			foreach (GameObject item2 in obj)
			{
				MatchContext current3 = MatchContext.Current;
				if (current3 != null && current3.SpawnedObjects.TryGetObjectId(item2, out var _))
				{
					continue;
				}
				foreach (GameObject item3 in list)
				{
					if (((Object)item2).name.StartsWith(((Object)item3).name))
					{
						MatchContext.Current?.SpawnedObjects.RegisterHostObject(item2, ((Object)item2).name, item2.transform.position, item2.transform.rotation);
						num++;
					}
				}
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(SpawnInteractables), "SpawnShit")]
		private static void SpawnPots_Postfix(SpawnInteractables __instance)
		{
			//IL_005a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0065: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			foreach (InteractablePot item in Object.FindObjectsOfType<InteractablePot>())
			{
				GameObject gameObject = ((Component)item).gameObject;
				MatchContext current = MatchContext.Current;
				if (current == null || !current.SpawnedObjects.TryGetObjectId(gameObject, out var _))
				{
					MatchContext.Current?.SpawnedObjects.RegisterHostObject(gameObject, ((Object)gameObject).name, gameObject.transform.position, gameObject.transform.rotation);
				}
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(SpawnInteractables), "SpawnOther")]
		private static void SpawnOther_Postfix(SpawnInteractables __instance)
		{
			//IL_005a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0065: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			foreach (InteractablePortal item in Object.FindObjectsOfType<InteractablePortal>())
			{
				GameObject gameObject = ((Component)item).gameObject;
				MatchContext current = MatchContext.Current;
				if (current == null || !current.SpawnedObjects.TryGetObjectId(gameObject, out var _))
				{
					MatchContext.Current?.SpawnedObjects.RegisterHostObject(gameObject, ((Object)gameObject).name, gameObject.transform.position, gameObject.transform.rotation);
				}
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(InteractableShadyGuy), "Start")]
		private static void InteractableShadyGuy_Start_Postfix(InteractableShadyGuy __instance)
		{
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			//IL_001d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0035: Unknown result type (might be due to invalid IL or missing references)
			//IL_003b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0040: Unknown result type (might be due to invalid IL or missing references)
			//IL_0046: Expected I4, but got Unknown
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				GameObject gameObject = ((Component)__instance).gameObject;
				Transform transform = gameObject.transform;
				EItemRarity rarity = __instance.rarity;
				MatchContext.Current?.SpawnedObjects.RegisterHostObject(gameObject, ((Object)gameObject).name, transform.position, transform.rotation, (int)rarity);
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(InteractableMicrowave), "Start")]
		private static void InteractableMicrowave_Start_Postfix(InteractableMicrowave __instance)
		{
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			//IL_001d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0035: Unknown result type (might be due to invalid IL or missing references)
			//IL_003b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0040: Unknown result type (might be due to invalid IL or missing references)
			//IL_0046: Expected I4, but got Unknown
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				GameObject gameObject = ((Component)__instance).gameObject;
				Transform transform = gameObject.transform;
				EItemRarity rarity = __instance.rarity;
				MatchContext.Current?.SpawnedObjects.RegisterHostObject(gameObject, ((Object)gameObject).name, transform.position, transform.rotation, (int)rarity);
			}
		}
	}
	[HarmonyPatch]
	public static class PickupPatches
	{
		private static readonly List<Pickup> _xpPickupBuffer = new List<Pickup>(256);

		private static readonly List<ulong> _alivePlayerIdsBuffer = new List<ulong>(16);

		[HarmonyPrefix]
		[HarmonyPatch(typeof(PickupManager), "SpawnPickup")]
		public static bool OnPickupSpawned_Prefix(ref Pickup __result, ref bool useRandomOffsetPosition)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			useRandomOffsetPosition = false;
			if (MatchContext.Current.Pickups.IsSpawningFromNetwork || SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(PickupManager), "SpawnPickup")]
		public static void OnPickupSpawned_Postfix(Pickup __result, int ePickup, Vector3 pos, int value)
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Server && !((Object)(object)__result == (Object)null) && !MatchContext.Current.Pickups.IsSpawningFromNetwork)
			{
				MatchContext.Current.Pickups.BroadcastPickupSpawned(__result, ePickup);
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(Pickup), "StartFollowingPlayer")]
		public static bool OnPickupStartFollow_Prefix(Pickup __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (MatchContext.Current.Pickups.IsProcessingRemoteCollection)
			{
				return true;
			}
			int pickupId = MatchContext.Current.Pickups.GetPickupId(__instance);
			if (pickupId == -1)
			{
				return false;
			}
			if (__instance.pickedUp)
			{
				return false;
			}
			ulong steamID = SteamUser.GetSteamID().m_SteamID;
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				MatchContext.Current.Pickups.SetPickupOwner(pickupId, steamID);
				SteamNetworkServer.Instance?.BroadcastMessage(new PickupCollectedMessage
				{
					PickupId = pickupId,
					CollectorSteamId = steamID
				});
				return true;
			}
			SteamNetworkClient.Instance?.SendMessage(new PickupCollectedMessage
			{
				PickupId = pickupId,
				CollectorSteamId = steamID
			});
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(Pickup), "ApplyPickup")]
		public static bool OnApplyPickup_Prefix(Pickup __instance)
		{
			//IL_000a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0010: Invalid comparison between Unknown and I4
			//IL_0013: Unknown result type (might be due to invalid IL or missing references)
			//IL_001a: Invalid comparison between Unknown and I4
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if ((int)__instance.ePickup == 4 || (int)__instance.ePickup == 9)
			{
				return true;
			}
			int pickupId = MatchContext.Current.Pickups.GetPickupId(__instance);
			bool flag = MatchContext.Current.Pickups.IsOwnedByLocal(pickupId);
			if (!flag)
			{
				MatchContext.Current.Pickups.ProcessPickupCollection(pickupId);
				return false;
			}
			return flag;
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(PickupManager), "DespawnPickup")]
		public static void OnPickupDespawned_Postfix(Pickup pickup)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server && Object.op_Implicit((Object)(object)pickup) && !MatchContext.Current.Pickups.IsProcessingNetworkDespawn)
			{
				int pickupId = MatchContext.Current.Pickups.GetPickupId(pickup);
				if (pickupId != -1)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(new PickupDespawnedMessage
					{
						PickupId = pickupId
					});
				}
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(PickupManager), "PickupAllXp")]
		public static bool OnPickupAllXp_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return false;
			}
			MatchContext.Current.Pickups.GetAllXpPickups(_xpPickupBuffer);
			if (_xpPickupBuffer.Count == 0)
			{
				return false;
			}
			GetAlivePlayerIds(_alivePlayerIdsBuffer);
			if (_alivePlayerIdsBuffer.Count == 0)
			{
				return false;
			}
			Random random = new Random();
			foreach (Pickup item in _xpPickupBuffer)
			{
				ulong num = _alivePlayerIdsBuffer[random.Next(_alivePlayerIdsBuffer.Count)];
				int pickupId = MatchContext.Current.Pickups.GetPickupId(item);
				if (pickupId != -1)
				{
					MatchContext.Current.Pickups.SetPickupOwner(pickupId, num);
					Transform playerTransform = GetPlayerTransform(num);
					if (!((Object)(object)playerTransform == (Object)null))
					{
						MatchContext.Current.Pickups.IsProcessingRemoteCollection = true;
						item.StartFollowingPlayer(playerTransform);
						MatchContext.Current.Pickups.IsProcessingRemoteCollection = false;
						SteamNetworkServer.Instance?.BroadcastMessage(new PickupCollectedMessage
						{
							PickupId = pickupId,
							CollectorSteamId = num
						});
					}
				}
			}
			return false;
		}

		private static void GetAlivePlayerIds(List<ulong> buffer)
		{
			buffer.Clear();
			GameManager instance = GameManager.Instance;
			if ((Object)(object)((instance != null) ? instance.player : null) != (Object)null && !GameManager.Instance.player.IsDead())
			{
				buffer.Add(SteamUser.GetSteamID().m_SteamID);
			}
			foreach (NetworkedPlayer item in MatchContext.Current?.RemotePlayers.GetAllPlayers())
			{
				if ((Object)(object)item != (Object)null && !item.State.IsDead)
				{
					buffer.Add(item.SteamId);
				}
			}
		}

		private static Transform GetPlayerTransform(ulong steamId)
		{
			ulong steamID = SteamUser.GetSteamID().m_SteamID;
			if (steamId == steamID)
			{
				GameManager instance = GameManager.Instance;
				if (instance == null)
				{
					return null;
				}
				MyPlayer player = instance.player;
				if (player == null)
				{
					return null;
				}
				return ((Component)player).transform;
			}
			NetworkedPlayer obj = MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(steamId));
			if (obj == null)
			{
				return null;
			}
			GameObject modelInstance = obj.ModelInstance;
			if (modelInstance == null)
			{
				return null;
			}
			return modelInstance.transform;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(PickupOrb), "OnCollisionEnter")]
		public static bool OnPickupOrbCollision_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			return SteamNetworkManager.Mode == SteamNetworkMode.Server;
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(PickupOrb), "OnCollisionEnter")]
		public static void OnPickupOrbCollision_Postfix(PickupOrb __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && SteamNetworkManager.Mode == SteamNetworkMode.Client && (Object)(object)__instance != (Object)null)
			{
				Object.Destroy((Object)(object)((Component)__instance).gameObject);
			}
		}

		public static void ProcessPendingSpawns()
		{
			MatchContext.Current.Pickups.ProcessPendingSpawns();
		}

		public static void ProcessPendingDespawns()
		{
			MatchContext.Current.Pickups.ProcessPendingDespawns();
		}
	}
	[HarmonyPatch]
	public static class RandomObjectPlacerPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch(typeof(RandomObjectPlacer), "RandomObjectSpawner")]
		public static bool RandomObjectSpawner_Prefix(RandomObjectPlacer __instance)
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(RandomObjectPlacer), "RandomObjectSpawner")]
		public static void RandomObjectSpawner_Postfix(RandomObjectPlacer __instance, RandomMapObject randomObject)
		{
			//IL_00da: Unknown result type (might be due to invalid IL or missing references)
			//IL_00e6: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server || randomObject == null)
			{
				return;
			}
			Il2CppArrayBase<GameObject> val = Object.FindObjectsOfType<GameObject>();
			int num = 0;
			foreach (GameObject item in (Il2CppArrayBase<GameObject>)(object)randomObject.prefabs)
			{
				if ((Object)(object)item == (Object)null || ((Object)item).name.Contains("Microwave"))
				{
					continue;
				}
				foreach (GameObject item2 in val)
				{
					if (((Object)item2).name.StartsWith(((Object)item).name) && !(((Object)item2).name == "BarrelMesh") && !(((Object)item2).name == "ArchCollider"))
					{
						MatchContext current3 = MatchContext.Current;
						if (current3 == null || !current3.SpawnedObjects.TryGetObjectId(item2, out var _))
						{
							MatchContext.Current?.SpawnedObjects.RegisterHostObject(item2, ((Object)item2).name, item2.transform.position, item2.transform.rotation);
							num++;
						}
					}
				}
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.Game
{
	[HarmonyPatch]
	public static class GameStatePatches
	{
		[HarmonyPatch(typeof(SteamManager), "Load", new Type[] { })]
		private static class SteamManagerLoadPatch
		{
			private static bool Prefix(SteamManager __instance)
			{
				return false;
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(GameManager), "StartPlaying")]
		public static void OnGameStarted()
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.None)
			{
				MatchContext.Current?.GameState.TransitionTo(GameLifecycleState.GameStarted);
				SteamNetworkClient.Instance?.SendMessage(new ClientPrefabsReadyMessage());
			}
		}

		private static bool ConfirmCharacterPatch_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			CharacterInfoUI val = Object.FindObjectOfType<CharacterInfoUI>();
			if (Object.op_Implicit((Object)(object)val))
			{
				Button val2 = ((IEnumerable<Button>)((Component)val).GetComponentsInChildren<Button>(true)).FirstOrDefault((Func<Button, bool>)((Button b) => ((Object)b).name == "B_Confirm"));
				if (Object.op_Implicit((Object)(object)val2))
				{
					((Component)val2).GetComponentInChildren<TMP_Text>().text = "Waiting for host..";
					((Component)val2).GetComponent<ResizeOnLocalization>().DelayedRefresh();
				}
			}
			return true;
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(MyPlayer), "Start")]
		private static void PlayerSpawned()
		{
			_ = SteamNetworkManager.Mode;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(MyTime), "Pause")]
		private static bool Pause_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (MatchContext.Current != null)
			{
				MatchContext current = MatchContext.Current;
				if (current == null)
				{
					return true;
				}
				return !current.GameState.HasGameStarted;
			}
			return true;
		}

		private static bool MyTime_Update_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			MyTime.paused = false;
			return true;
		}

		private static bool MyTime_FixedUpdate_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			MyTime.paused = false;
			return true;
		}

		private static bool Unpause_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			return false;
		}

		private static bool StartMap_Prefix()
		{
			_ = SteamNetworkManager.Mode;
			return true;
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(CharacterInfoUI), "OnCharacterSelected")]
		private static void CharacterSelectionPatch_Postfix(MyButtonCharacter btn)
		{
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && Object.op_Implicit((Object)(object)btn))
			{
				SteamNetworkLobby.Instance.MemberSetCharacter(btn.characterData.eCharacter);
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(MapStatsInfoUi), "SetConfig")]
		private static void MapStatsInfoUISetConfig_Postfix(MapStatsInfoUi __instance, RunConfig runConfig)
		{
			//IL_002b: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && runConfig != null && Object.op_Implicit((Object)(object)runConfig.mapData) && SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkLobby.Instance.SetMap(runConfig.mapData.eMap);
				SteamNetworkLobby.Instance.SetTier(runConfig.mapTierIndex);
				SteamNetworkLobby.Instance.SetChallenge(runConfig.challenge);
				Object.op_Implicit((Object)(object)runConfig.challenge);
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(SkinSelection), "SetCurrentlySelected")]
		private static void SkinSelectionCurrenlySelected_Postfix(SkinSelection __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				SteamNetworkLobby.Instance.MemberSetSkinType((ESkinType)__instance.currentlySelected);
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(MapController), "StartNewMap")]
		private static void MapControllerStartNewMap_Prefix(RunConfig newRunConfig)
		{
			//IL_001e: Unknown result type (might be due to invalid IL or missing references)
			//IL_0028: Expected O, but got Unknown
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				int seed = SteamNetworkLobby.Instance.Seed;
				Random.InitState(seed);
				MapGenerator.seed = seed;
				MyRandom.random = new Random(seed);
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(RunConfig), "GetEnemyHp")]
		private static void RunConfig_GetEnemyHp_Postfix(ref float __result)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				__result *= Preferences.EnemyHpModifer.Value;
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(RunConfig), "GetEnemyDamage")]
		private static void RunConfig_GetEnemyDamage_Postfix(ref float __result)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				__result *= Preferences.EnemyDmgModifer.Value;
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(RunConfig), "GetEnemySpeed")]
		private static void RunConfig_GetEnemySpeed_Postfix(ref float __result)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				__result *= Preferences.EnemySpeedModifer.Value;
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(MinimapCamera), "Start")]
		private static void MinimapCamera_Start_Postfix()
		{
			_ = SteamNetworkManager.Mode;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(GameManager), "OnDied")]
		private static bool GameManager_OnDied_Prefix(GameManager __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			MatchContext.Current?.LocalPlayer.UpdatePlayerDeath(isDead: true);
			MatchContext current = MatchContext.Current;
			if (current == null || !current.RemotePlayers.AreAllRemotePlayersDead())
			{
				__instance._isGameOver_k__BackingField = false;
				PlayerCameraPatches.ActivateSpectatorMode();
				return false;
			}
			__instance._isGameOver_k__BackingField = true;
			MatchContext.Current?.GameState.TransitionTo(GameLifecycleState.GameOver);
			return true;
		}

		private static void EnterSpectatorMode()
		{
			try
			{
				PlayerCamera val = Object.FindObjectOfType<PlayerCamera>();
				if ((Object)(object)val != (Object)null)
				{
					val.cameraState = (ECameraState)1;
				}
			}
			catch (Exception)
			{
			}
		}

		public static void PrintGeneratedMapList()
		{
			MapData currentMap = MapController.currentMap;
			if (!Object.op_Implicit((Object)(object)currentMap))
			{
				ModLogger.Error("MapData is NULL!");
				return;
			}
			Il2CppReferenceArray<StageData> stages = currentMap.stages;
			if (stages == null)
			{
				ModLogger.Error("Stage List is NULL!");
				return;
			}
			for (int i = 0; i < ((Il2CppArrayBase<StageData>)(object)stages).Count; i++)
			{
				StageData val = ((Il2CppArrayBase<StageData>)(object)stages)[i];
				if (Object.op_Implicit((Object)(object)val))
				{
					val.GetName();
				}
			}
		}
	}
	[HarmonyPatch]
	public static class MapControllerPatches
	{
		private static bool _isNetworkLoading;

		internal static bool IsNetworkLoading => _isNetworkLoading;

		internal static void SetNetworkLoading(bool value)
		{
			_isNetworkLoading = value;
		}

		private static bool LoadNextStage_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				return _isNetworkLoading;
			}
			return true;
		}

		private static void LoadNextStage_Postfix()
		{
			GameStatePatches.PrintGeneratedMapList();
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				int index = MapController.index;
				MatchContext.Current?.HostEnemies?.Dispose();
				LoadStageMessage tMsg = new LoadStageMessage
				{
					StageIndex = index
				};
				SteamNetworkServer.Instance.BroadcastMessage(tMsg);
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Client && _isNetworkLoading)
			{
				MatchContext.Current?.TimeSync.Initialize();
				_isNetworkLoading = false;
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(MapController), "RestartRun")]
		public static bool RestartRun_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			return false;
		}
	}
	[HarmonyPatch(typeof(MapGenerator))]
	public static class MapGeneratorPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch(typeof(MapGenerator), "GenerateMap", new Type[] { typeof(int) })]
		public static void GenerateMap_Prefix(ref int seed)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				seed = SteamNetworkLobby.Instance.Seed;
			}
		}
	}
	[HarmonyPatch(typeof(Maze))]
	public static class MazePatches
	{
		[HarmonyPrefix]
		[HarmonyPatch(typeof(Maze), "Generate")]
		public static void Generate_Prefix(ref int seed)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				seed = SteamNetworkLobby.Instance.Seed;
			}
		}
	}
	[HarmonyPatch(typeof(MazeHeightGenerator))]
	public static class MazeHeightGeneratorPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch(typeof(MazeHeightGenerator), "GenerateHeight")]
		public static void GenerateHeights_Prefix(ref int seed)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				seed = SteamNetworkLobby.Instance.Seed;
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(MazeHeightGenerator), "GenerateHeightHein")]
		public static void GenerateHeightHein_Prefix(ref int seed)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				seed = SteamNetworkLobby.Instance.Seed;
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(MazeHeightGenerator), "GenerateHeightMe")]
		public static void GenerateHeightMe_Prefix(ref int seed)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				seed = SteamNetworkLobby.Instance.Seed;
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.FinalBoss
{
	[HarmonyPatch(typeof(BossLamp))]
	internal static class BossLampPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("OnTriggerEnter")]
		private static bool OnTriggerEnter_Prefix(BossLamp __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			MatchContext current = MatchContext.Current;
			if (current == null || !current.SpawnedObjects.CanSendNetworkMessages)
			{
				return true;
			}
			MatchContext current2 = MatchContext.Current;
			if (current2 == null || !current2.SpawnedObjects.TryGetObjectId(((Component)__instance).gameObject, out var id))
			{
				return true;
			}
			BossLampChargeMessage tMsg = new BossLampChargeMessage
			{
				LampId = id,
				IsStarting = true
			};
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				SteamNetworkClient.Instance?.SendMessage(tMsg);
				return false;
			}
			return true;
		}

		[HarmonyPrefix]
		[HarmonyPatch("OnTriggerExit")]
		private static bool OnTriggerExit_Prefix(BossLamp __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			MatchContext current = MatchContext.Current;
			if (current == null || !current.SpawnedObjects.CanSendNetworkMessages)
			{
				return true;
			}
			MatchContext current2 = MatchContext.Current;
			if (current2 == null || !current2.SpawnedObjects.TryGetObjectId(((Component)__instance).gameObject, out var id))
			{
				return true;
			}
			BossLampChargeMessage tMsg = new BossLampChargeMessage
			{
				LampId = id,
				IsStarting = false
			};
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				SteamNetworkClient.Instance?.SendMessage(tMsg);
				return false;
			}
			return true;
		}
	}
	[HarmonyPatch(typeof(BossOrbBleed))]
	internal static class BossOrbBleedPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("FloatMovement")]
		private static bool FloatMovement_Prefix(BossOrbBleed __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}
	}
	[HarmonyPatch(typeof(BossOrb))]
	internal static class BossOrbFollowingPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("FloatMovement")]
		private static bool FloatMovement_Prefix(BossOrb __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}
	}
	[HarmonyPatch(typeof(BossOrbShooty))]
	internal static class BossOrbShootyPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("FloatMovement")]
		private static bool FloatMovement_Prefix(BossOrbShooty __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}
	}
	[HarmonyPatch(typeof(BossPylon))]
	internal static class BossPylonPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("OnTriggerEnter")]
		private static bool OnTriggerEnter_Prefix(BossPylon __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			MatchContext current = MatchContext.Current;
			if (current == null || !current.SpawnedObjects.CanSendNetworkMessages)
			{
				return true;
			}
			MatchContext current2 = MatchContext.Current;
			if (current2 == null || !current2.SpawnedObjects.TryGetObjectId(((Component)__instance).gameObject, out var id))
			{
				return true;
			}
			BossPylonChargeMessage tMsg = new BossPylonChargeMessage
			{
				PylonId = id,
				IsStarting = true
			};
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				SteamNetworkClient.Instance?.SendMessage(tMsg);
				return false;
			}
			return true;
		}

		[HarmonyPrefix]
		[HarmonyPatch("OnTriggerExit")]
		private static bool OnTriggerExit_Prefix(BossPylon __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			MatchContext current = MatchContext.Current;
			if (current == null || !current.SpawnedObjects.CanSendNetworkMessages)
			{
				return true;
			}
			MatchContext current2 = MatchContext.Current;
			if (current2 == null || !current2.SpawnedObjects.TryGetObjectId(((Component)__instance).gameObject, out var id))
			{
				return true;
			}
			BossPylonChargeMessage tMsg = new BossPylonChargeMessage
			{
				PylonId = id,
				IsStarting = false
			};
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
			}
			else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				SteamNetworkClient.Instance?.SendMessage(tMsg);
				return false;
			}
			return true;
		}
	}
	[HarmonyPatch(typeof(FinalFightController))]
	internal static class FinalFightControllerPatches
	{
		private static readonly List<NetworkedPlayer> _alivePlayers = new List<NetworkedPlayer>(16);

		[HarmonyPrefix]
		[HarmonyPatch("StartPylons")]
		private static void StartPylons_Prefix()
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				Random.InitState(SteamNetworkLobby.Instance.Seed);
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch("StartPylons")]
		private static void StartPylons_Postfix(FinalFightController __instance)
		{
			//IL_004d: Unknown result type (might be due to invalid IL or missing references)
			//IL_0053: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode == SteamNetworkMode.None || SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			foreach (BossPylon item in (Il2CppArrayBase<BossPylon>)(object)__instance.pylons)
			{
				Transform transform = ((Component)item).gameObject.transform;
				MatchContext.Current?.SpawnedObjects.RegisterHostObject(((Component)item).gameObject, "BossPylon", transform.position, transform.rotation);
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch("SpawnBoss")]
		private static bool SpawnBoss_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch("SpecialAttacks")]
		private static bool SpecialAttacks_Prefix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch("SpawnOrbsBleed")]
		private static void SpawnOrbsBleed_Prefix()
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			_alivePlayers.Clear();
			IEnumerable<NetworkedPlayer> enumerable = MatchContext.Current?.RemotePlayers.GetAllPlayers();
			if (enumerable != null)
			{
				foreach (NetworkedPlayer item in enumerable)
				{
					if ((Object)(object)item != (Object)null && !item.State.IsDead)
					{
						_alivePlayers.Add(item);
					}
				}
			}
			if (_alivePlayers.Count > 0)
			{
				int index = Random.Range(0, _alivePlayers.Count);
				NetworkedPlayer networkedPlayer = _alivePlayers[index];
				MatchContext.Current?.FinalBossOrbs.QueueNextTarget(networkedPlayer.SteamId);
			}
			else
			{
				MatchContext.Current?.FinalBossOrbs.QueueNextTarget((MatchContext.Current?.LocalPlayer.LocalPlayer?.SteamId).GetValueOrDefault());
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch("SpawnOrbsBleed")]
		private static void SpawnOrbsBleed_Postfix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				BroadcastOrbSpawn(OrbType.Bleed);
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch("SpawnOrbsFollowing")]
		private static void SpawnOrbsFollowing_Prefix()
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			_alivePlayers.Clear();
			IEnumerable<NetworkedPlayer> enumerable = MatchContext.Current?.RemotePlayers.GetAllPlayers();
			if (enumerable != null)
			{
				foreach (NetworkedPlayer item in enumerable)
				{
					if ((Object)(object)item != (Object)null && !item.State.IsDead)
					{
						_alivePlayers.Add(item);
					}
				}
			}
			if (_alivePlayers.Count > 0)
			{
				int index = Random.Range(0, _alivePlayers.Count);
				NetworkedPlayer networkedPlayer = _alivePlayers[index];
				MatchContext.Current?.FinalBossOrbs.QueueNextTarget(networkedPlayer.SteamId);
			}
			else
			{
				MatchContext.Current?.FinalBossOrbs.QueueNextTarget((MatchContext.Current?.LocalPlayer.LocalPlayer?.SteamId).GetValueOrDefault());
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch("SpawnOrbsFollowing")]
		private static void SpawnOrbsFollowing_Postfix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				BroadcastOrbSpawn(OrbType.Following);
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch("SpawnOrbsShooty")]
		private static void SpawnOrbsShooty_Prefix()
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			_alivePlayers.Clear();
			IEnumerable<NetworkedPlayer> enumerable = MatchContext.Current?.RemotePlayers.GetAllPlayers();
			if (enumerable != null)
			{
				foreach (NetworkedPlayer item in enumerable)
				{
					if ((Object)(object)item != (Object)null && !item.State.IsDead)
					{
						_alivePlayers.Add(item);
					}
				}
			}
			if (_alivePlayers.Count > 0)
			{
				int index = Random.Range(0, _alivePlayers.Count);
				NetworkedPlayer networkedPlayer = _alivePlayers[index];
				MatchContext.Current?.FinalBossOrbs.QueueNextTarget(networkedPlayer.SteamId);
			}
			else
			{
				MatchContext.Current?.FinalBossOrbs.QueueNextTarget((MatchContext.Current?.LocalPlayer.LocalPlayer?.SteamId).GetValueOrDefault());
			}
		}

		[HarmonyPostfix]
		[HarmonyPatch("SpawnOrbsShooty")]
		private static void SpawnOrbsShooty_Postfix()
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				BroadcastOrbSpawn(OrbType.Shooty);
			}
		}

		private static void BroadcastOrbSpawn(OrbType orbType)
		{
			(ulong, uint)? tuple = MatchContext.Current?.FinalBossOrbs.GetNextTargetAndOrbId();
			if (tuple.HasValue)
			{
				while (tuple.HasValue)
				{
					(ulong, uint) value = tuple.Value;
					ulong item = value.Item1;
					uint item2 = value.Item2;
					FinalBossOrbSpawnedMessage tMsg = new FinalBossOrbSpawnedMessage
					{
						OrbType = orbType,
						TargetId = item,
						OrbId = item2
					};
					SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
					tuple = MatchContext.Current?.FinalBossOrbs.GetNextTargetAndOrbId();
				}
				MatchContext.Current?.FinalBossOrbs.ClearQueueNextTarget();
			}
		}
	}
	[HarmonyPatch(typeof(GraveyardBossRoom))]
	internal static class GraveyardBossRoomPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("Activate")]
		private static void Activate_Prefix(GraveyardBossRoom __instance)
		{
			//IL_0050: Unknown result type (might be due to invalid IL or missing references)
			//IL_0056: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b3: Unknown result type (might be due to invalid IL or missing references)
			//IL_00b9: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode == SteamNetworkMode.None || SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			foreach (BossLamp item in (Il2CppArrayBase<BossLamp>)(object)__instance.lamps)
			{
				Transform transform = ((Component)item).gameObject.transform;
				MatchContext.Current?.SpawnedObjects.RegisterHostObject(((Component)item).gameObject, "BossLamp", transform.position, transform.rotation);
			}
			if (Object.op_Implicit((Object)(object)__instance.interactableGhostBossLeave))
			{
				Transform transform2 = ((Component)__instance.interactableGhostBossLeave).gameObject.transform;
				MatchContext.Current?.SpawnedObjects.RegisterHostObject(((Component)__instance.interactableGhostBossLeave).gameObject, "InteractableGhostBossLeave", transform2.position, transform2.rotation);
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.Enemies
{
	[HarmonyPatch(typeof(EnemyMovementRb))]
	internal static class EnemyMovementRbPatches
	{
		[HarmonyPrefix]
		[HarmonyPatch("MyFixedUpdate")]
		public static bool MyFixedUpdate_Prefix(EnemyMovementRb __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch("TryClimbWall")]
		public static bool TryClimbWall_Prefix(EnemyMovementRb __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch("CheckGrounded")]
		public static bool CheckGrounded_Prefix(EnemyMovementRb __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch("DashStart")]
		public static bool DashStart_Prefix(EnemyMovementRb __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch("StartMovement")]
		public static bool StartMovement_Prefix(EnemyMovementRb __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch("FindNextPosition")]
		public static bool FindNextPosition_Prefix(EnemyMovementRb __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}
	}
	[HarmonyPatch]
	public static class EnemyPatches
	{
		[HarmonyPatch]
		public static class SpawnPositions_Patch
		{
			private struct PlayerSpawnData
			{
				public Vector3 Position;

				public Vector3 Forward;

				public bool IsValid;
			}

			private static readonly PlayerSpawnData[] _playerCache = new PlayerSpawnData[16];

			private static readonly List<RemotePlayerManager.PlayerTarget> _tempPlayerList = new List<RemotePlayerManager.PlayerTarget>(16);

			private static int _activePlayerCount = 0;

			private static int _lastCacheFrame = -1;

			private const int CACHE_REFRESH_INTERVAL = 30;

			private const float MIN_SPAWN_RADIUS = 25f;

			private const float MAX_SPAWN_RADIUS = 50f;

			private static void UpdatePlayerCache()
			{
				//IL_00bc: Unknown result type (might be due to invalid IL or missing references)
				//IL_00c1: Unknown result type (might be due to invalid IL or missing references)
				//IL_00d7: Unknown result type (might be due to invalid IL or missing references)
				//IL_00dc: Unknown result type (might be due to invalid IL or missing references)
				int frameCount = Time.frameCount;
				if (frameCount == _lastCacheFrame)
				{
					return;
				}
				_lastCacheFrame = frameCount;
				if (frameCount % 30 == 0 || _activePlayerCount == 0)
				{
					_tempPlayerList.Clear();
					MatchContext.Current?.RemotePlayers.FillAllPlayerTargets(_tempPlayerList);
					_activePlayerCount = 0;
					for (int i = 0; i < _tempPlayerList.Count && i < _playerCache.Length; i++)
					{
						if (Object.op_Implicit((Object)(object)_tempPlayerList[i].Transform))
						{
							_activePlayerCount++;
						}
					}
				}
				for (int j = 0; j < _activePlayerCount; j++)
				{
					RemotePlayerManager.PlayerTarget playerTarget = _tempPlayerList[j];
					if (Object.op_Implicit((Object)(object)playerTarget.Transform))
					{
						_playerCache[j].Position = playerTarget.Transform.position;
						_playerCache[j].Forward = playerTarget.Transform.forward;
						_playerCache[j].IsValid = true;
					}
					else
					{
						_playerCache[j].IsValid = false;
					}
				}
			}

			private static int GetRandomValidPlayerIndex()
			{
				if (_activePlayerCount == 0)
				{
					return -1;
				}
				int num = Random.Range(0, _activePlayerCount);
				int num2 = 0;
				while (!_playerCache[num].IsValid && num2 < _activePlayerCount)
				{
					num = (num + 1) % _activePlayerCount;
					num2++;
				}
				if (!_playerCache[num].IsValid)
				{
					return -1;
				}
				return num;
			}

			[HarmonyPrefix]
			[HarmonyPatch(typeof(SpawnPositions), "GetEnemySpawnPosition")]
			public static bool GetEnemySpawnPosition(ref Vector3 __result, EnemyData enemyData, int attempts, bool useDirectionBias)
			{
				//IL_0025: Unknown result type (might be due to invalid IL or missing references)
				//IL_002a: Unknown result type (might be due to invalid IL or missing references)
				//IL_002b: Unknown result type (might be due to invalid IL or missing references)
				//IL_0030: Unknown result type (might be due to invalid IL or missing references)
				//IL_0034: Unknown result type (might be due to invalid IL or missing references)
				//IL_0039: Unknown result type (might be due to invalid IL or missing references)
				//IL_004b: Unknown result type (might be due to invalid IL or missing references)
				//IL_0051: Unknown result type (might be due to invalid IL or missing references)
				//IL_005a: Unknown result type (might be due to invalid IL or missing references)
				//IL_0060: Unknown result type (might be due to invalid IL or missing references)
				//IL_0066: Unknown result type (might be due to invalid IL or missing references)
				//IL_006f: Unknown result type (might be due to invalid IL or missing references)
				//IL_0074: Unknown result type (might be due to invalid IL or missing references)
				if (SteamNetworkManager.Mode == SteamNetworkMode.None)
				{
					return true;
				}
				UpdatePlayerCache();
				int randomValidPlayerIndex = GetRandomValidPlayerIndex();
				if (randomValidPlayerIndex < 0)
				{
					return true;
				}
				Vector3 position = _playerCache[randomValidPlayerIndex].Position;
				Vector2 insideUnitCircle = Random.insideUnitCircle;
				Vector2 normalized = ((Vector2)(ref insideUnitCircle)).normalized;
				float num = Random.Range(25f, 50f);
				__result = new Vector3(position.x + normalized.x * num, position.y, position.z + normalized.y * num);
				return false;
			}

			[HarmonyPrefix]
			[HarmonyPatch(typeof(SpawnPositions), "GetEnemySpawnPositionBiased")]
			public static bool GetEnemySpawnPositionBiased(ref Vector3 __result, EnemyData enemyData, float playerDirectionBias, int attempts)
			{
				//IL_0026: Unknown result type (might be due to invalid IL or missing references)
				//IL_002b: Unknown result type (might be due to invalid IL or missing references)
				//IL_002c: Unknown result type (might be due to invalid IL or missing references)
				//IL_0031: Unknown result type (might be due to invalid IL or missing references)
				//IL_0045: Unknown result type (might be due to invalid IL or missing references)
				//IL_004a: Unknown result type (might be due to invalid IL or missing references)
				//IL_004e: Unknown result type (might be due to invalid IL or missing references)
				//IL_0053: Unknown result type (might be due to invalid IL or missing references)
				//IL_0054: Unknown result type (might be due to invalid IL or missing references)
				//IL_005f: Unknown result type (might be due to invalid IL or missing references)
				//IL_0065: Unknown result type (might be due to invalid IL or missing references)
				//IL_006a: Unknown result type (might be due to invalid IL or missing references)
				//IL_006c: Unknown result type (might be due to invalid IL or missing references)
				//IL_0071: Unknown result type (might be due to invalid IL or missing references)
				//IL_0075: Unknown result type (might be due to invalid IL or missing references)
				//IL_007a: Unknown result type (might be due to invalid IL or missing references)
				//IL_008e: Unknown result type (might be due to invalid IL or missing references)
				//IL_0094: Unknown result type (might be due to invalid IL or missing references)
				//IL_009f: Unknown result type (might be due to invalid IL or missing references)
				//IL_00a5: Unknown result type (might be due to invalid IL or missing references)
				//IL_00ab: Unknown result type (might be due to invalid IL or missing references)
				//IL_00b6: Unknown result type (might be due to invalid IL or missing references)
				//IL_00bb: Unknown result type (might be due to invalid IL or missing references)
				if (SteamNetworkManager.Mode == SteamNetworkMode.None)
				{
					return true;
				}
				UpdatePlayerCache();
				int randomValidPlayerIndex = GetRandomValidPlayerIndex();
				if (randomValidPlayerIndex < 0)
				{
					return true;
				}
				PlayerSpawnData playerSpawnData = _playerCache[randomValidPlayerIndex];
				Vector3 position = playerSpawnData.Position;
				Vector3 forward = playerSpawnData.Forward;
				forward.y = 0f;
				((Vector3)(ref forward)).Normalize();
				Vector2 insideUnitCircle = Random.insideUnitCircle;
				Vector2 normalized = ((Vector2)(ref insideUnitCircle)).normalized;
				Vector3 val = Vector3.Slerp(new Vector3(normalized.x, 0f, normalized.y), forward, playerDirectionBias);
				Vector3 normalized2 = ((Vector3)(ref val)).normalized;
				float num = Random.Range(25f, 50f);
				__result = new Vector3(position.x + normalized2.x * num, position.y, position.z + normalized2.z * num);
				return false;
			}

			public static void ClearCache()
			{
				_activePlayerCount = 0;
				_lastCacheFrame = -1;
				Array.Clear(_playerCache, 0, _playerCache.Length);
				_tempPlayerList.Clear();
			}
		}

		public static class EnemyMovement_GetTargetPosition_Patch
		{
			private struct PlayerCacheEntry
			{
				public Transform Transform;

				public Rigidbody Rigidbody;

				public Vector3 Position;
			}

			private struct EnemyTarget
			{
				public int PlayerIndex;

				public Rigidbody Rigidbody;

				public int LastUpdateFrame;
			}

			private const int MAX_ENEMIES_CAP = 4000;

			private static readonly EnemyTarget[] _enemyTargets = new EnemyTarget[4000];

			private static readonly bool[] _enemyHasTarget = new bool[4000];

			private static readonly PlayerCacheEntry[] _playerCache = new PlayerCacheEntry[16];

			private static readonly List<RemotePlayerManager.PlayerTarget> _tempTargets = new List<RemotePlayerManager.PlayerTarget>(16);

			private static int _playerCount = 0;

			private static int _lastGlobalUpdateFrame = -1;

			private const int PLAYER_REFRESH_INTERVAL = 30;

			private const int UPDATE_INTERVAL = 16;

			public static void MultiplayerTargetOverride(EnemyMovementRb __instance, ref Vector3 __result)
			{
				//IL_0175: Unknown result type (might be due to invalid IL or missing references)
				//IL_017a: Unknown result type (might be due to invalid IL or missing references)
				//IL_00a5: Unknown result type (might be due to invalid IL or missing references)
				//IL_00aa: Unknown result type (might be due to invalid IL or missing references)
				//IL_00c7: Unknown result type (might be due to invalid IL or missing references)
				//IL_00cc: Unknown result type (might be due to invalid IL or missing references)
				//IL_00ce: Unknown result type (might be due to invalid IL or missing references)
				//IL_00d3: Unknown result type (might be due to invalid IL or missing references)
				//IL_0159: Unknown result type (might be due to invalid IL or missing references)
				//IL_015e: Unknown result type (might be due to invalid IL or missing references)
				if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
				{
					return;
				}
				int frameCount = Time.frameCount;
				if (_lastGlobalUpdateFrame != frameCount)
				{
					UpdatePlayerCache(frameCount);
					_lastGlobalUpdateFrame = frameCount;
				}
				if (_playerCount == 0)
				{
					return;
				}
				uint id = __instance.enemy.id;
				if (id >= 4000)
				{
					return;
				}
				bool num = _enemyHasTarget[id];
				ref EnemyTarget reference = ref _enemyTargets[id];
				bool flag = ((frameCount + (int)id) & 0xF) == 0;
				if (!num || flag || reference.PlayerIndex < 0 || reference.PlayerIndex >= _playerCount || !Object.op_Implicit((Object)(object)_playerCache[reference.PlayerIndex].Transform))
				{
					Vector3 position = ((Component)__instance).transform.position;
					float num2 = float.MaxValue;
					int num3 = -1;
					for (int i = 0; i < _playerCount; i++)
					{
						Vector3 val = _playerCache[i].Position - position;
						float sqrMagnitude = ((Vector3)(ref val)).sqrMagnitude;
						if (sqrMagnitude < num2)
						{
							num2 = sqrMagnitude;
							num3 = i;
						}
					}
					if (num3 >= 0)
					{
						reference.PlayerIndex = num3;
						reference.Rigidbody = _playerCache[num3].Rigidbody;
						reference.LastUpdateFrame = frameCount;
						_enemyHasTarget[id] = true;
						if (Object.op_Implicit((Object)(object)reference.Rigidbody))
						{
							__instance.enemy.target = reference.Rigidbody;
						}
						__result = _playerCache[num3].Position;
					}
				}
				else
				{
					__result = _playerCache[reference.PlayerIndex].Position;
				}
			}

			private static void UpdatePlayerCache(int currentFrame)
			{
				//IL_00fd: Unknown result type (might be due to invalid IL or missing references)
				//IL_0102: Unknown result type (might be due to invalid IL or missing references)
				if (currentFrame % 30 == 0 || _playerCount == 0)
				{
					_tempTargets.Clear();
					MatchContext.Current?.RemotePlayers.FillAllPlayerTargets(_tempTargets);
					_playerCount = 0;
					for (int i = 0; i < _tempTargets.Count && i < _playerCache.Length; i++)
					{
						if (Object.op_Implicit((Object)(object)_tempTargets[i].Transform))
						{
							_playerCache[_playerCount].Transform = _tempTargets[i].Transform;
							_playerCache[_playerCount].Rigidbody = _tempTargets[i].Rigidbody;
							_playerCount++;
						}
					}
				}
				for (int j = 0; j < _playerCount; j++)
				{
					if (Object.op_Implicit((Object)(object)_playerCache[j].Transform))
					{
						_playerCache[j].Position = _playerCache[j].Transform.position;
					}
				}
			}

			public static void OnEnemyDied(uint enemyId)
			{
				if (enemyId < 4000)
				{
					_enemyHasTarget[enemyId] = false;
				}
			}

			public static void ClearCache()
			{
				Array.Clear(_enemyHasTarget, 0, _enemyHasTarget.Length);
				_playerCount = 0;
			}
		}

		[HarmonyPatch]
		public static class EnemyManager_GetNumMaxEnemies_Patch
		{
			private static float SpawnRateMultiplier => Preferences.EnemySpawnRate.Value;

			[HarmonyPostfix]
			[HarmonyPatch(typeof(EnemyManager), "GetNumMaxEnemies")]
			public static void GetNumMaxEnemies(ref int __result)
			{
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server && SpawnRateMultiplier >= 1f)
				{
					float num = (float)__result * SpawnRateMultiplier;
					__result = Mathf.CeilToInt(num);
				}
			}
		}

		private static bool _isSpawningFromNetwork;

		private static bool _isApplyingNetworkDamage;

		internal static bool IsSpawningFromNetwork => _isSpawningFromNetwork;

		[HarmonyPrefix]
		[HarmonyPatch(typeof(EnemyManager), "SpawnEnemy", new Type[]
		{
			typeof(EnemyData),
			typeof(int),
			typeof(bool),
			typeof(EEnemyFlag),
			typeof(bool)
		})]
		private static bool SpawnEnemy_BySummoner_Prefix()
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				return _isSpawningFromNetwork;
			}
			return true;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(EnemyManager), "SpawnEnemy", new Type[]
		{
			typeof(EnemyData),
			typeof(Vector3),
			typeof(int),
			typeof(bool),
			typeof(EEnemyFlag),
			typeof(bool),
			typeof(float)
		})]
		private static bool SpawnEnemy_ByPos_Prefix()
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				return _isSpawningFromNetwork;
			}
			return true;
		}

		internal static void SetSpawningFromNetwork(bool value)
		{
			_isSpawningFromNetwork = value;
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(Enemy), "InitEnemy")]
		private static void OnEnemyAwake_Postfix(Enemy __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server && !((Object)(object)__instance == (Object)null) && __instance.id != 0 && !IsSpawningFromNetwork)
			{
				MatchContext.Current?.EnemySpawn.RegisterHostEnemy(__instance);
				MatchContext.Current?.SmartSpatial.RegisterEnemy(__instance);
				MatchContext.Current?.EnemySpawn.BroadcastEnemySpawn(__instance);
			}
		}

		public static bool Enemy_MyFixedUpdate_Prefix(Enemy __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				return false;
			}
			return true;
		}

		public static bool Enemy_MyUpdate_Prefix(Enemy __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				return false;
			}
			return true;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(Enemy), "TeleportToPlayer")]
		public static bool Enemy_TeleportToPlayer_Prefix(Enemy __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return false;
			}
			return true;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(Enemy), "StartTeleporting")]
		public static bool Enemy_StartTeleporting_Prefix(Enemy __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return false;
			}
			return true;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(Enemy), "TryTeleport")]
		public static bool Enemy_TryTeleport_Prefix(Enemy __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return false;
			}
			return true;
		}

		internal static void SetApplyingNetworkDamage(bool applying)
		{
			_isApplyingNetworkDamage = applying;
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(Enemy), "Damage")]
		public static void Enemy_Damage_Postfix(Enemy __instance, DamageContainer damageContainer)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && !_isApplyingNetworkDamage)
			{
				MatchContext.Current?.EnemySpawn.BroadcastEnemyDamage(__instance, damageContainer);
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(EnemyMovementRb), "GetTargetPosition")]
		public static bool GetTargetPosition_Smart(EnemyMovementRb __instance, ref Vector3 __result)
		{
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			//IL_003a: Unknown result type (might be due to invalid IL or missing references)
			//IL_003b: Unknown result type (might be due to invalid IL or missing references)
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return true;
			}
			uint id = __instance.enemy.id;
			Vector3 position = default(Vector3);
			MatchContext current = MatchContext.Current;
			if (current != null && current.SmartSpatial.TryGetTargetPosition(id, out position))
			{
				__result = position;
				return false;
			}
			return true;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(Enemy), "EnemyDied", new Type[] { })]
		public static void OnEnemyDied_NoArgs_Prefix(Enemy __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				MatchContext.Current?.EnemySpawn.ProcessEnemyDeath(__instance);
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(Enemy), "EnemyDied", new Type[] { typeof(DamageContainer) })]
		public static void OnEnemyDied_WithDamage_Prefix(Enemy __instance)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None)
			{
				MatchContext.Current?.EnemySpawn.ProcessEnemyDeath(__instance);
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(Enemy), "Heal")]
		public static bool Heal_Prefix(Enemy __instance)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				return true;
			}
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(Enemy), "IsRunningFromPlayer")]
		public static bool IsRunningFromPlayer_Prefix(ref bool __result)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			__result = false;
			return false;
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(Enemy), "IsStationary")]
		public static bool IsStationary_Prefix(ref bool __result)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			__result = false;
			return false;
		}
	}
	[HarmonyPatch(typeof(EnemyStats))]
	internal static class EnemyStatsPatches
	{
		[HarmonyPostfix]
		[HarmonyPatch("GetHp")]
		private static void GetHp_Postfix(Enemy enemy, ref float __result)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && SteamNetworkManager.Mode == SteamNetworkMode.Server)
			{
				__result *= Preferences.EnemyHpModifer.Value;
			}
		}
	}
	[HarmonyPatch(typeof(Enemy))]
	internal static class GhostEnemyPatches
	{
		[HarmonyPostfix]
		[HarmonyPatch("InitEnemy")]
		private static void InitEnemy_Postfix(Enemy __instance)
		{
			//IL_001b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0020: Unknown result type (might be due to invalid IL or missing references)
			//IL_005f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0064: Unknown result type (might be due to invalid IL or missing references)
			//IL_0065: Unknown result type (might be due to invalid IL or missing references)
			//IL_0067: Invalid comparison between Unknown and I4
			//IL_0069: Unknown result type (might be due to invalid IL or missing references)
			//IL_006c: Invalid comparison between Unknown and I4
			if (SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			TargetSwitcher targetSwitcher = ((Component)__instance).gameObject.AddComponent<TargetSwitcher>();
			if (((object)__instance.enemyData.enemyName/*cast due to .constrained prefix*/).ToString().Contains("GhostGrave"))
			{
				targetSwitcher.Initialize(__instance, pickCloseTarget: true);
				targetSwitcher.SetSwitchIntervalRange(7f, 12f);
				targetSwitcher.SetSwitchMaxDistance(30f);
				return;
			}
			EEnemyFlag enemyFlag = __instance.enemyFlag;
			if ((int)enemyFlag != 4)
			{
				if ((int)enemyFlag == 32)
				{
					targetSwitcher.Initialize(__instance);
					targetSwitcher.SetSwitchIntervalRange(30f, 50f);
					targetSwitcher.SetSwitchMaxDistance(300f);
				}
			}
			else
			{
				targetSwitcher.Initialize(__instance);
				targetSwitcher.SetSwitchIntervalRange(20f, 40f);
				targetSwitcher.SetSwitchMaxDistance(300f);
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.Enemies.SpecialAttacks
{
	[HarmonyPatch(typeof(SpecialAttackController))]
	internal static class EnemySpecialAttackPatches
	{
		private static bool _allowFromNetwork = false;

		private static readonly List<NetworkedPlayer> _alivePlayers = new List<NetworkedPlayer>(16);

		internal static void SetAllowFromNetwork(bool allow)
		{
			_allowFromNetwork = allow;
		}

		[HarmonyPrefix]
		[HarmonyPatch("UseSpecialAttack")]
		private static bool UseSpecialAttack_Prefix()
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined)
			{
				return true;
			}
			if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
			{
				return _allowFromNetwork;
			}
			return true;
		}

		[HarmonyPostfix]
		[HarmonyPatch("UseSpecialAttack")]
		private static void UseSpecialAttack_Postfix(SpecialAttackController __instance, EnemySpecialAttack attack)
		{
			if (SteamNetworkLobbyManager.State != SteamNetworkLobbyState.Joined || SteamNetworkManager.Mode != SteamNetworkMode.Server)
			{
				return;
			}
			Enemy enemy = __instance.enemy;
			if ((Object)(object)enemy == (Object)null)
			{
				return;
			}
			uint id = enemy.id;
			if ((Object)(object)MatchContext.Current?.HostEnemies.GetTrackedEnemy(id) == (Object)null)
			{
				return;
			}
			_alivePlayers.Clear();
			IEnumerable<NetworkedPlayer> enumerable = MatchContext.Current?.RemotePlayers.GetAllPlayers();
			if (enumerable != null)
			{
				foreach (NetworkedPlayer item in enumerable)
				{
					if ((Object)(object)item != (Object)null && !item.State.IsDead)
					{
						_alivePlayers.Add(item);
					}
				}
			}
			MatchContext current2 = MatchContext.Current;
			if (current2 != null && current2.LocalPlayer.IsInitialized && (Object)(object)MatchContext.Current.LocalPlayer.LocalPlayer != (Object)null && !MatchContext.Current.LocalPlayer.LocalPlayerState.IsDead)
			{
				_alivePlayers.Add(MatchContext.Current?.LocalPlayer.LocalPlayer);
			}
			if (_alivePlayers.Count != 0)
			{
				NetworkedPlayer networkedPlayer = _alivePlayers[Random.Range(0, _alivePlayers.Count)];
				if ((Object)(object)networkedPlayer.CachedRigidbody != (Object)null)
				{
					enemy.target = networkedPlayer.CachedRigidbody;
				}
				EnemySpecialAttackMessage tMsg = new EnemySpecialAttackMessage
				{
					EnemyId = id,
					AttackName = attack.attackName,
					TargetSteamId = networkedPlayer.SteamId
				};
				SteamNetworkServer.Instance?.BroadcastMessage(tMsg);
			}
		}
	}
}
namespace Megabonk.BonkWithFriends.HarmonyPatches.Combat
{
	[HarmonyPatch]
	public static class PlayerCombatPatches
	{
		public static class Patch_PlayerHealth_Heal
		{
			private static void Postfix(PlayerHealth __instance, float amount, int __result)
			{
				try
				{
					if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined && __result > 0)
					{
						if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
						{
							SteamNetworkServer.Instance?.BroadcastMessage(new PlayerHealedMessage
							{
								HealAmount = __result,
								Hp = __instance.hp,
								MaxHp = __instance.maxHp
							});
						}
						else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
						{
							SteamNetworkClient.Instance?.SendMessage(new PlayerHealedMessage
							{
								HealAmount = __result,
								Hp = __instance.hp,
								MaxHp = __instance.maxHp
							});
						}
					}
				}
				catch (Exception ex)
				{
					ModLogger.Error("Error in ChestOpenPatch: " + ex.Message);
					ModLogger.Error("Stack trace: " + ex.StackTrace);
				}
			}
		}

		private static int _lastKnownLevel = 1;

		public static void OnPlayerDamaged(PlayerHealth __instance, float damage, Vector3 direction, string damageSource)
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined)
			{
				SteamUser.GetSteamID();
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(new PlayerDamagedMessage
					{
						Damage = damage,
						Hp = __instance.hp,
						MaxHp = __instance.maxHp,
						Shield = __instance.shield,
						MaxShield = __instance.maxShield
					});
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance?.SendMessage(new PlayerDamagedMessage
					{
						Damage = damage,
						Hp = __instance.hp,
						MaxHp = __instance.maxHp,
						Shield = __instance.shield,
						MaxShield = __instance.maxShield
					});
				}
			}
		}

		public static void OnPlayerDied(PlayerHealth __instance)
		{
			if (SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined)
			{
				ulong steamID = SteamUser.GetSteamID().m_SteamID;
				if (SteamNetworkManager.Mode == SteamNetworkMode.Server)
				{
					SteamNetworkServer.Instance?.BroadcastMessage(new PlayerDiedMessage
					{
						SteamUserId = steamID
					});
				}
				else if (SteamNetworkManager.Mode == SteamNetworkMode.Client)
				{
					SteamNetworkClient.Instance?.SendMessage(new PlayerDiedMessage
					{
						SteamUserId = steamID
					});
				}
			}
		}
	}
	[HarmonyPatch]
	public static class ProjectileSyncPatches
	{
		[HarmonyPatch]
		public static class ProjectileUpdate_Unified_Patch
		{
			private static IEnumerable<MethodBase> TargetMethods()
			{
				yield return AccessTools.Method(typeof(ProjectileMelee), "MyUpdate", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectileCringeSword), "MyUpdate", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectileHeroSword), "MyUpdate", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectileScythe), "MyUpdate", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectileBanana), "MyFixedUpdate", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectileCringeSword), "MyFixedUpdate", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectileHeroSword), "MyFixedUpdate", (Type[])null, (Type[])null);
			}

			[HarmonyPrefix]
			public static void Prefix(ProjectileBase __instance)
			{
				if (RemoteAttackController.TryGetProjectileOwner(__instance, out var playerId))
				{
					if (!Object.op_Implicit((Object)(object)MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(playerId))))
					{
						Object.Destroy((Object)(object)((Component)__instance).gameObject);
						RemoteAttackController.CleanupRemoteProjectile(__instance);
					}
					else
					{
						MatchContext.Current?.PlayerTransformContext.PushContext(playerId);
					}
				}
			}

			[HarmonyPostfix]
			public static void Postfix(ProjectileBase __instance)
			{
				if (RemoteAttackController.TryGetProjectileOwner(__instance, out var _))
				{
					MatchContext.Current?.PlayerTransformContext.PopContext();
				}
			}
		}

		[HarmonyPatch]
		public static class ProjectileTryInit_Unified_Postfix_Patch
		{
			private static IEnumerable<MethodBase> TargetMethods()
			{
				yield return AccessTools.Method(typeof(ProjectileFirefield), "TryInit", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectilePoisonFlask), "TryInit", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectileMines), "TryInit", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectileWhirlwind), "TryInit", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectileArrow), "TryInit", (Type[])null, (Type[])null);
				yield return AccessTools.Method(typeof(ProjectileShotgun), "TryInit", (Type[])null, (Type[])null);
			}

			[HarmonyPrefix]
			public static void Prefix(ProjectileBase __instance)
			{
				//IL_0053: Unknown result type (might be due to invalid IL or missing references)
				//IL_0081: Unknown result type (might be due to invalid IL or missing references)
				if (!RemoteAttackController.TryGetProjectileOwner(__instance, out var playerId))
				{
					return;
				}
				NetworkedPlayer networkedPlayer = MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(playerId));
				if (!Object.op_Implicit((Object)(object)networkedPlayer))
				{
					Object.Destroy((Object)(object)((Component)__instance).gameObject);
					RemoteAttackController.CleanupRemoteProjectile(__instance);
					return;
				}
				((Component)__instance).transform.position = networkedPlayer.ModelInstance.transform.position;
				ProjectileMines val = (ProjectileMines)(object)((__instance is ProjectileMines) ? __instance : null);
				if (val != null && (Object)(object)val.rb != (Object)null)
				{
					val.rb.MovePosition(((Component)networkedPlayer).transform.position);
				}
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(ProjectileBase), "TryInit")]
		public static void ProjectileBase_Prefix_TryInit(ProjectileBase __instance)
		{
			//IL_0048: Unknown result type (might be due to invalid IL or missing references)
			//IL_005f: Unknown result type (might be due to invalid IL or missing references)
			if (RemoteAttackController.TryGetProjectileOwner(__instance, out var playerId))
			{
				NetworkedPlayer networkedPlayer = MatchContext.Current?.RemotePlayers.GetPlayer(new CSteamID(playerId));
				if (!Object.op_Implicit((Object)(object)networkedPlayer))
				{
					Object.Destroy((Object)(object)((Component)__instance).gameObject);
					RemoteAttackController.CleanupRemoteProjectile(__instance);
				}
				else
				{
					_ = ((Component)__instance).transform.position;
					((Component)__instance).transform.position = networkedPlayer.ModelInstance.transform.position;
				}
			}
		}
	}
	[HarmonyPatch]
	public static class WeaponSyncPatches
	{
		private static readonly Dictionary<WeaponAttack, uint> _localAttackIds = new Dictionary<WeaponAttack, uint>();

		private static uint _nextAttackId = 1u;

		private static readonly Dictionary<WeaponAttack, int> _projectileIndices = new Dictionary<WeaponAttack, int>();

		private static bool _isSpawningFromNetwork = false;

		private static readonly Dictionary<WeaponBase, ulong> _weaponOwners = new Dictionary<WeaponBase, ulong>();

		private static readonly Dictionary<WeaponAttack, ulong> _attackOwners = new Dictionary<WeaponAttack, ulong>();

		[HarmonyPostfix]
		[HarmonyPatch(typeof(WeaponAttack), "SuccessfullySpawnedProjectile")]
		private static void SuccessfullySpawnedProjectile_Postfix(WeaponAttack __instance, ProjectileBase projectile)
		{
			//IL_0057: Unknown result type (might be due to invalid IL or missing references)
			//IL_005c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0063: Unknown result type (might be due to invalid IL or missing references)
			//IL_0068: Unknown result type (might be due to invalid IL or missing references)
			//IL_009d: Unknown result type (might be due to invalid IL or missing references)
			//IL_00a2: Unknown result type (might be due to invalid IL or missing references)
			//IL_00aa: Unknown result type (might be due to invalid IL or missing references)
			//IL_00af: Unknown result type (might be due to invalid IL or missing references)
			//IL_007f: Unknown result type (might be due to invalid IL or missing references)
			//IL_0080: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c4: Unknown result type (might be due to invalid IL or missing references)
			//IL_00c6: Unknown result type (might be due to invalid IL or missing references)
			if (!ShouldSynchronize() || _isSpawningFromNetwork || !IsLocalPlayerAttack(__instance) || (Object)(object)projectile == (Object)null || !_projectileIndices.TryGetValue(__instance, out var value))
			{
				return;
			}
			try
			{
				uint value3;
				if (value == 0)
				{
					uint value2 = _nextAttackId++;
					_localAttackIds[__instance] = value2;
					Vector3 position = ((Component)projectile).transform.position;
					Quaternion rotation = ((Component)projectile).transform.rotation;
					MatchContext.Current?.LocalPlayer.SendAttackStarted(__instance.weaponBase, position, rotation);
				}
				else if (_localAttackIds.TryGetValue(__instance, out value3))
				{
					Vector3 position2 = ((Component)projectile).transform.position;
					Quaternion rotation2 = ((Component)projectile).transform.rotation;
					MatchContext.Current?.LocalPlayer.SendProjectileSpawned(value3, value, position2, rotation2);
				}
				if (IsLastProjectile(__instance, value))
				{
					_projectileIndices.Remove(__instance);
					_localAttackIds.Remove(__instance);
				}
			}
			catch (Exception)
			{
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(WeaponAttack), "SpawnProjectile")]
		private static bool SpawnProjectile_UnifiedPrefix(WeaponAttack __instance, int projectileIndex)
		{
			if (!ShouldSynchronize())
			{
				return true;
			}
			if (RemoteAttackController.TryGetRemoteAttackData(__instance, out var data))
			{
				_isSpawningFromNetwork = true;
				SpawnRemoteProjectile(__instance, projectileIndex, data);
				_isSpawningFromNetwork = false;
				return false;
			}
			if (IsLocalPlayerAttack(__instance))
			{
				_projectileIndices[__instance] = projectileIndex;
			}
			return true;
		}

		private static void SpawnRemoteProjectile(WeaponAttack attack, int projectileIndex, RemoteAttackController.RemoteAttackData data)
		{
			//IL_009f: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ab: Unknown result type (might be due to invalid IL or missing references)
			//IL_0088: Unknown result type (might be due to invalid IL or missing references)
			//IL_0093: Unknown result type (might be due to invalid IL or missing references)
			object obj;
			if (attack == null)
			{
				obj = null;
			}
			else
			{
				WeaponBase weaponBase = attack.weaponBase;
				obj = ((weaponBase != null) ? weaponBase.weaponData : null);
			}
			if ((Object)obj == (Object)null)
			{
				return;
			}
			PoolManager instance = PoolManager.Instance;
			if ((Object)(object)instance == (Object)null)
			{
				return;
			}
			ProjectileBase projectile = instance.GetProjectile(attack);
			if ((Object)(object)projectile == (Object)null)
			{
				return;
			}
			GameObject gameObject = ((Component)projectile).gameObject;
			if ((Object)(object)gameObject == (Object)null)
			{
				return;
			}
			gameObject.SetActive(true);
			Transform transform = ((Component)projectile).transform;
			GameObject prefabProjectile = attack.prefabProjectile;
			if ((Object)(object)((prefabProjectile != null) ? prefabProjectile.transform : null) != (Object)null)
			{
				transform.localScale = attack.prefabProjectile.transform.localScale * data.Size;
			}
			transform.position = data.Position;
			transform.rotation = data.Rotation;
			MatchContext.Current?.RemotePlayers.PushProjectileSpawnContext(data.PlayerId);
			projectile.Set(attack.weaponBase, attack, projectileIndex);
			RemoteAttackController.MarkProjectileAsRemote(projectile, data.PlayerId);
			try
			{
				Action a_SpawnedProjectile = attack.A_SpawnedProjectile;
				if (a_SpawnedProjectile != null)
				{
					a_SpawnedProjectile.Invoke();
				}
			}
			catch (Exception)
			{
			}
		}

		public static void SetWeaponOwner(WeaponBase weapon, ulong steamId)
		{
			if (weapon != null)
			{
				_weaponOwners[weapon] = steamId;
			}
		}

		public static bool TryGetWeaponOwner(WeaponBase weapon, out ulong steamId)
		{
			steamId = 0uL;
			if (weapon == null)
			{
				return false;
			}
			return _weaponOwners.TryGetValue(weapon, out steamId);
		}

		public static bool TryGetAttackOwner(WeaponAttack attack, out ulong steamId)
		{
			steamId = 0uL;
			if ((Object)(object)attack == (Object)null)
			{
				return false;
			}
			return _attackOwners.TryGetValue(attack, out steamId);
		}

		[HarmonyPostfix]
		[HarmonyPatch(typeof(PoolManager), "GetAttack")]
		private static void PoolManager_GetAttack_Postfix(ref WeaponAttack __result, WeaponBase weaponBase)
		{
			if (SteamNetworkManager.Mode != SteamNetworkMode.None && weaponBase != null && !((Object)(object)__result == (Object)null) && _weaponOwners.TryGetValue(weaponBase, out var value))
			{
				_attackOwners[__result] = value;
			}
		}

		[HarmonyPrefix]
		[HarmonyPatch(typeof(WeaponUtility), "GetAttackSizeMultiplier")]
		private static bool GetAttackSizeMultiplier_Prefix(WeaponBase weaponBase, ref float __result)
		{
			if (SteamNetworkManager.Mode == SteamNetworkMode.None)
			{
				return true;
			}
			if (_weaponOwners.ContainsKey(weaponBase))
			{
				__result = 1f;
				return false;
			}
			return true;
		}

		private static bool IsLocalPlayerAttack(WeaponAttack attack)
		{
			if ((Object)(object)attack == (Object)null)
			{
				return false;
			}
			MatchContext current = MatchContext.Current;
			bool? obj;
			if (current == null)
			{
				obj = null;
			}
			else
			{
				PlayerInventory playerInventory = current.LocalPlayer.GetPlayerInventory();
				obj = ((playerInventory != null) ? new bool?(playerInventory.weaponInventory.weapons.ContainsValue(attack.weaponBase)) : ((bool?)null));
			}
			bool? flag = obj;
			bool valueOrDefault = flag == true;
			bool flag2 = (Object)(object)attack.player == (Object)(object)MyPlayer.Instance;
			return valueOrDefault || flag2;
		}

		private static bool ShouldSynchronize()
		{
			return SteamNetworkLobbyManager.State == SteamNetworkLobbyState.Joined;
		}

		private static bool IsLastProjectile(WeaponAttack attack, int projectileIndex)
		{
			int? obj;
			if (attack == null)
			{
				obj = null;
			}
			else
			{
				WeaponBase weaponBase = attack.weaponBase;
				obj = ((weaponBase != null) ? new int?(weaponBase.weaponData.projectiles) : ((int?)null));
			}
			int num = obj ?? 1;
			return projectileIndex >= num - 1;
		}

		public static void OnLeaveLobby()
		{
			_localAttackIds.Clear();
			_projectileIndices.Clear();
			_weaponOwners.Clear();
			_attackOwners.Clear();
			_nextAttackId = 1u;
			_isSpawningFromNetwork = false;
		}
	}
}
namespace Megabonk.BonkWithFriends.Debugging
{
	public static class SceneDumper
	{
		public static void Dump(int maxDepth = 3)
		{
			Camera main = Camera.main;
			if (!((Object)(object)main == (Object)null))
			{
				Transform val = ((Component)main).transform;
				while ((Object)(object)val.parent != (Object)null)
				{
					val = val.parent;
				}
				DumpTransform(val, 0, maxDepth);
			}
			NetworkedPlayer networkedPlayer = MatchContext.Current?.LocalPlayer.LocalPlayer;
			if ((Object)(object)networkedPlayer != (Object)null)
			{
				DumpTransform(((Component)networkedPlayer).transform, 0, 2);
			}
		}

		private static void DumpTransform(Transform t, int depth, int maxDepth)
		{
			if ((Object)(object)t == (Object)null)
			{
				return;
			}
			StringBuilder stringBuilder = new StringBuilder();
			for (int i = 0; i < depth; i++)
			{
				stringBuilder.Append("  ");
			}
			GameObject gameObject = ((Component)t).gameObject;
			Il2CppArrayBase<Component> components = gameObject.GetComponents<Component>();
			stringBuilder.Append("- ").Append(((Object)gameObject).name).Append(" [");
			for (int j = 0; j < components.Length; j++)
			{
				Component val = components[j];
				if (!((Object)(object)val == (Object)null))
				{
					string name = ((object)val).GetType().Name;
					stringBuilder.Append(name);
					if (j < components.Length - 1)
					{
						stringBuilder.Append(',');
					}
				}
			}
			stringBuilder.Append(']');
			string text = ((Object)gameObject).name.ToLowerInvariant();
			if (text.Contains("player") || text.Contains("pawn") || text.Contains("character"))
			{
				stringBuilder.Append("  <-- LIKELY PLAYER");
			}
			if (depth < maxDepth)
			{
				for (int k = 0; k < t.childCount; k++)
				{
					DumpTransform(t.GetChild(k), depth + 1, maxDepth);
				}
			}
		}

		private static string GetPath(Transform t)
		{
			StringBuilder stringBuilder = new StringBuilder();
			List<Transform> list = new List<Transform>();
			Transform val = t;
			while ((Object)(object)val != (Object)null)
			{
				list.Add(val);
				val = val.parent;
			}
			for (int num = list.Count - 1; num >= 0; num--)
			{
				stringBuilder.Append('/').Append(((Object)list[num]).name);
			}
			return stringBuilder.ToString();
		}
	}
}
namespace Megabonk.BonkWithFriends.Debug
{
	[RegisterTypeInIl2Cpp]
	public class DebugVisualizer : MonoBehaviour
	{
		public int lineCount = 100;

		public float radius = 3f;

		private static Material _lineMaterial;

		public DebugVisualizer(IntPtr intPtr)
			: base(intPtr)
		{
		}

		public DebugVisualizer()
			: base(ClassInjector.DerivedConstructorPointer<DebugVisualizer>())
		{
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private static void CreateLineMaterial()
		{
			//IL_0018: Unknown result type (might be due to invalid IL or missing references)
			//IL_0022: Expected O, but got Unknown
			if (!((Object)(object)_lineMaterial != (Object)null))
			{
				_lineMaterial = new Material(Shader.Find("Hidden/Internal-Colored"));
				((Object)_lineMaterial).hideFlags = (HideFlags)61;
				_lineMaterial.SetInt("_SrcBlend", 5);
				_lineMaterial.SetInt("_DstBlend", 10);
				_lineMaterial.SetInt("_Cull", 0);
				_lineMaterial.SetInt("_ZWrite", 0);
			}
		}

		public void OnRenderObject()
		{
			//IL_001c: Unknown result type (might be due to invalid IL or missing references)
			//IL_005b: Unknown result type (might be due to invalid IL or missing references)
			CreateLineMaterial();
			_lineMaterial.SetPass(0);
			GL.PushMatrix();
			GL.MultMatrix(((Component)this).transform.localToWorldMatrix);
			GL.Begin(1);
			for (int i = 0; i < lineCount; i++)
			{
				float num = (float)i / (float)lineCount;
				float num2 = num * (float)Math.PI * 2f;
				GL.Color(new Color(num, 1f - num, 0f, 0.8f));
				GL.Vertex3(0f, 0f, 0f);
				GL.Vertex3(Mathf.Cos(num2) * radius, Mathf.Sin(num2) * radius, 0f);
			}
			GL.End();
			GL.PopMatrix();
		}
	}
}
namespace Megabonk.BonkWithFriends.Debug.UI
{
	public static class NetProfiler
	{
		private sealed class ProfilerData
		{
			public readonly byte OpCode;

			private int _count;

			private int _bytes;

			private float _prevBytesPerSec;

			public long TotalCount { get; private set; }

			public long TotalBytes { get; private set; }

			public float Rate { get; private set; }

			public float BytesPerSec { get; private set; }

			public float AvgSize { get; private set; }

			public float PeakBytesPerSec { get; private set; }

			public string Trend { get; private set; } = "--";

			public ProfilerData(byte opCode)
			{
				OpCode = opCode;
			}

			public void Update(int byteSize)
			{
				_count++;
				_bytes += byteSize;
				TotalCount++;
				TotalBytes += byteSize;
			}

			public void EndFrame(float dt)
			{
				BytesPerSec = (float)_bytes / dt;
				Rate = (float)_count / dt;
				AvgSize = ((_count > 0) ? ((float)_bytes / (float)_count) : 0f);
				if (BytesPerSec > PeakBytesPerSec)
				{
					PeakBytesPerSec = BytesPerSec;
				}
				float num = ((_prevBytesPerSec > 0f) ? ((BytesPerSec - _prevBytesPerSec) / _prevBytesPerSec) : 0f);
				Trend = ((num > 0.1f) ? "▲" : ((num < -0.1f) ? "▼" : "─"));
				_prevBytesPerSec = BytesPerSec;
				_count = 0;
				_bytes = 0;
			}
		}

		private static readonly Dictionary<byte, ProfilerData> _sent = new Dictionary<byte, ProfilerData>();

		private static readonly Dictionary<byte, ProfilerData> _received = new Dictionary<byte, ProfilerData>();

		private static readonly List<ProfilerData> _sortBuf = new List<ProfilerData>();

		private static readonly StringBuilder _sb = new StringBuilder();

		private static float _lastTickTime;

		private static float _lastMessageTime;

		private const string Separator = "------------------------------------------------------------------------";

		public static float MinRateThreshold = 0.1f;

		public static float BandwidthBudget = 204800f;

		public static string DisplayString { get; private set; } = "NetProfiler Initializing...";

		public static int DisplayLineCount { get; private set; } = 1;

		public static void TrackMessageSent(byte opCode, int byteSize)
		{
			if (!_sent.TryGetValue(opCode, out var value))
			{
				value = (_sent[opCode] = new ProfilerData(opCode));
			}
			value.Update(byteSize);
			_lastMessageTime = Time.unscaledTime;
		}

		public static void TrackMessageReceived(byte opCode, int byteSize)
		{
			if (!_received.TryGetValue(opCode, out var value))
			{
				value = (_received[opCode] = new ProfilerData(opCode));
			}
			value.Update(byteSize);
			_lastMessageTime = Time.unscaledTime;
		}

		public static void UpdateDisplay()
		{
			float num = Time.unscaledTime - _lastTickTime;
			if (num < 0.001f)
			{
				num = 1f;
			}
			_lastTickTime = Time.unscaledTime;
			foreach (ProfilerData value2 in _sent.Values)
			{
				value2.EndFrame(num);
			}
			foreach (ProfilerData value3 in _received.Values)
			{
				value3.EndFrame(num);
			}
			float num2 = SectionBandwidth(_sent);
			float num3 = SectionBandwidth(_received);
			float num4 = num2 + num3;
			float num5 = Time.unscaledTime - _lastMessageTime;
			string value = ((num5 > 2f) ? $" ⚠ No messages for {num5:F1}s!" : "");
			_sb.Clear();
			_sb.AppendLine("=== Network Profiler ===");
			StringBuilder sb = _sb;
			StringBuilder stringBuilder = sb;
			StringBuilder.AppendInterpolatedStringHandler handler = new StringBuilder.AppendInterpolatedStringHandler(43, 3, sb);
			handler.AppendLiteral("Update: ");
			handler.AppendFormatted(num, "F2");
			handler.AppendLiteral("s | Threshold: >");
			handler.AppendFormatted(MinRateThreshold, "F1");
			handler.AppendLiteral(" msg/s | F3: Toggle");
			handler.AppendFormatted(value);
			stringBuilder.AppendLine(ref handler);
			_sb.AppendLine();
			sb = _sb;
			StringBuilder stringBuilder2 = sb;
			handler = new StringBuilder.AppendInterpolatedStringHandler(20, 3, sb);
			handler.AppendLiteral("Bandwidth: ");
			handler.AppendFormatted(FormatBytes(num4));
			handler.AppendLiteral("/s of ");
			handler.AppendFormatted(FormatBytes(BandwidthBudget));
			handler.AppendLiteral("/s ");
			handler.AppendFormatted(BudgetTag(num4));
			stringBuilder2.AppendLine(ref handler);
			sb = _sb;
			StringBuilder stringBuilder3 = sb;
			handler = new StringBuilder.AppendInterpolatedStringHandler(21, 2, sb);
			handler.AppendLiteral("  Sent: ");
			handler.AppendFormatted(FormatBytes(num2));
			handler.AppendLiteral("/s | Recv: ");
			handler.AppendFormatted(FormatBytes(num3));
			handler.AppendLiteral("/s");
			stringBuilder3.AppendLine(ref handler);
			_sb.AppendLine();
			_sb.AppendLine("--- SENT ---");
			AppendSection(_sb, _sent);
			_sb.AppendLine();
			_sb.AppendLine("--- RECEIVED ---");
			AppendSection(_sb, _received);
			DisplayString = _sb.ToString();
			int num6 = 0;
			string displayString = DisplayString;
			for (int i = 0; i < displayString.Length; i++)
			{
				if (displayString[i] == '\n')
				{
					num6++;
				}
			}
			DisplayLineCount = num6 + 1;
		}

		private static float SectionBandwidth(Dictionary<byte, ProfilerData> data)
		{
			float num = 0f;
			foreach (ProfilerData value in data.Values)
			{
				num += value.BytesPerSec;
			}
			return num;
		}

		private static string BudgetTag(float total)
		{
			float num = total / BandwidthBudget;
			if (num > 0.8f)
			{
				return "[CRITICAL]";
			}
			if (num > 0.5f)
			{
				return "[WARNING]";
			}
			return "[GOOD]";
		}

		private static void AppendSection(StringBuilder sb, Dictionary<byte, ProfilerData> data)
		{
			_sortBuf.Clear();
			float num = 0f;
			foreach (ProfilerData value2 in data.Values)
			{
				if (!(value2.Rate < MinRateThreshold))
				{
					_sortBuf.Add(value2);
					num += value2.BytesPerSec;
				}
			}
			if (_sortBuf.Count == 0)
			{
				sb.AppendLine("  (No activity above threshold)");
				return;
			}
			_sortBuf.Sort((ProfilerData a, ProfilerData b) => b.BytesPerSec.CompareTo(a.BytesPerSec));
			StringBuilder stringBuilder = sb;
			StringBuilder stringBuilder2 = stringBuilder;
			StringBuilder.AppendInterpolatedStringHandler handler = new StringBuilder.AppendInterpolatedStringHandler(6, 7, stringBuilder);
			handler.AppendFormatted<string>("Op", -20);
			handler.AppendLiteral(" ");
			handler.AppendFormatted<string>("Rate", -8);
			handler.AppendLiteral(" ");
			handler.AppendFormatted<string>("BW", -10);
			handler.AppendLiteral(" ");
			handler.AppendFormatted<string>("Peak", -10);
			handler.AppendLiteral(" ");
			handler.AppendFormatted<string>("Avg", -8);
			handler.AppendLiteral(" ");
			handler.AppendFormatted<string>("%", -5);
			handler.AppendLiteral(" ");
			handler.AppendFormatted("Trend");
			stringBuilder2.AppendLine(ref handler);
			sb.AppendLine("------------------------------------------------------------------------");
			foreach (ProfilerData item in _sortBuf)
			{
				MessageType opCode = (MessageType)item.OpCode;
				float value = ((num > 0f) ? (item.BytesPerSec / num * 100f) : 0f);
				stringBuilder = sb;
				StringBuilder stringBuilder3 = stringBuilder;
				handler = new StringBuilder.AppendInterpolatedStringHandler(9, 7, stringBuilder);
				handler.AppendFormatted(opCode, -20);
				handler.AppendLiteral(" ");
				handler.AppendFormatted(item.Rate, 5, "F1");
				handler.AppendLiteral("/s ");
				handler.AppendFormatted<string>(FormatBytes(item.BytesPerSec), -10);
				handler.AppendLiteral(" ");
				handler.AppendFormatted<string>(FormatBytes(item.PeakBytesPerSec), -10);
				handler.AppendLiteral(" ");
				handler.AppendFormatted<string>(FormatBytes(item.AvgSize), -8);
				handler.AppendLiteral(" ");
				handler.AppendFormatted(value, 4, "F1");
				handler.AppendLiteral("% ");
				handler.AppendFormatted(item.Trend);
				stringBuilder3.AppendLine(ref handler);
			}
			sb.AppendLine("------------------------------------------------------------------------");
			stringBuilder = sb;
			StringBuilder stringBuilder4 = stringBuilder;
			handler = new StringBuilder.AppendInterpolatedStringHandler(2, 3, stringBuilder);
			handler.AppendFormatted<string>("TOTAL", -20);
			handler.AppendLiteral(" ");
			handler.AppendFormatted<string>("", 8);
			handler.AppendLiteral(" ");
			handler.AppendFormatted<string>(FormatBytes(num), -10);
			stringBuilder4.AppendLine(ref handler);
		}

		private static string FormatBytes(float bytes)
		{
			if (!(bytes >= 1048576f))
			{
				if (!(bytes >= 1024f))
				{
					return $"{bytes:F0} B";
				}
				return $"{bytes / 1024f:F2} KB";
			}
			return $"{bytes / 1048576f:F2} MB";
		}
	}
	[RegisterTypeInIl2Cpp]
	public class NetProfilerGui : MonoBehaviour
	{
		private bool _showProfiler;

		private float _nextUpdateTime;

		private Vector2 _scrollPos;

		private Texture2D _bgTexture;

		private GUIStyle _style;

		private Rect _windowRect = new Rect(20f, 20f, 500f, 520f);

		private const float UpdateInterval = 1f;

		private const float LineHeight = 14f;

		private const float TitleBarHeight = 20f;

		private const float ScrollPadding = 10f;

		public NetProfilerGui(IntPtr ptr)
			: base(ptr)
		{
		}//IL_0015: Unknown result type (might be due to invalid IL or missing references)
		//IL_001a: Unknown result type (might be due to invalid IL or missing references)


		public NetProfilerGui()
			: base(ClassInjector.DerivedConstructorPointer<NetProfilerGui>())
		{
			//IL_0015: Unknown result type (might be due to invalid IL or missing references)
			//IL_001a: Unknown result type (might be due to invalid IL or missing references)
			ClassInjector.DerivedConstructorBody((Il2CppObjectBase)(object)this);
		}

		private void Awake()
		{
			//IL_0003: Unknown result type (might be due to invalid IL or missing references)
			//IL_000d: Expected O, but got Unknown
			//IL_0029: Unknown result type (might be due to invalid IL or missing references)
			//IL_006c: Unknown result type (might be due to invalid IL or missing references)
			//IL_0071: Unknown result type (might be due to invalid IL or missing references)
			//IL_0078: Unknown result type (might be due to invalid IL or missing references)
			//IL_0084: Expected O, but got Unknown
			//IL_00d3: Unknown result type (might be due to invalid IL or missing references)
			_bgTexture = new Texture2D(1, 1);
			_bgTexture.SetPixel(0, 0, new Color(0.1f, 0.1f, 0.1f, 0.85f));
			_bgTexture.Apply();
			Font font = Font.CreateDynamicFontFromOSFont("Consolas", 12) ?? Font.CreateDynamicFontFromOSFont("Courier New", 12) ?? Font.CreateDynamicFontFromOSFont("monospace", 12);
			_style = new GUIStyle
			{
				font = font,
				wordWrap = false
			};
			_style.padding.left = 5;
			_style.padding.right = 5;
			_style.padding.top = 5;
			_style.padding.bottom = 5;
			_style.normal.textColor = Color.white;
			_style.normal.background = _bgTexture;
		}

		private void Update()
		{
			if (Input.GetKeyDown((KeyCode)284))
			{
				_showProfiler = !_showProfiler;
			}
			if (_showProfiler && Time.unscaledTime > _nextUpdateTime)
			{
				_nextUpdateTime = Time.unscaledTime + 1f;
				NetProfiler.UpdateDisplay();
			}
		}

		private void OnGUI()
		{
			//IL_0010: Unknown result type (might be due to invalid IL or missing references)
			//IL_002b: Unknown result type (might be due to invalid IL or missing references)
			//IL_0030: Unknown result type (might be due to invalid IL or missing references)
			if (_showProfiler)
			{
				_windowRect = GUI.Window(1234, _windowRect, WindowFunction.op_Implicit((Action<int>)DrawWindow), "Network Profiler");
			}
		}

		private void DrawWindow(int _)
		{
			//IL_005a: Unknown result type (might be due to invalid IL or missing references)
			//IL_0060: Unknown result type (might be due to invalid IL or missing references)
			//IL_0071: Unknown result type (might be due to invalid IL or missing references)
			//IL_0076: Unknown result type (might be due to invalid IL or missing references)
			//IL_007b: Unknown result type (might be due to invalid IL or missing references)
			//IL_008c: Unknown result type (might be due to invalid IL or missing references)
			//IL_00ba: Unknown result type (might be due to invalid IL or missing references)
			float num = ((Rect)(ref _windowRect)).height - 20f - 10f;
			float num2 = Mathf.Max((float)NetProfiler.DisplayLineCount * 14f, num);
			float num3 = ((Rect)(ref _windowRect)).width - 30f;
			_scrollPos = GUI.BeginScrollView(new Rect(5f, 20f, ((Rect)(ref _windowRect)).width - 10f, num), _scrollPos, new Rect(0f, 0f, num3, num2));
			GUI.Label(new Rect(0f, 0f, num3, num2), NetProfiler.DisplayString, _style);
			GUI.EndScrollView();
			GUI.DragWindow(new Rect(0f, 0f, 10000f, 20f));
		}
	}
}
