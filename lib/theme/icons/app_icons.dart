import 'package:lucide_icons/lucide_icons.dart';

/// UI 框架图标：语义化 token。
///
/// 设计意图：Tab/按钮/设置项等"语义固定、不持久化"的图标全部在此定义
/// 一次，调用点只引用 token——换图标只改本文件一行，全仓调用点自动跟随。
/// token 以语义/所在界面命名（而非图标形状），同一图标跨文件复用同一 token。
abstract final class AppIcons {
  // ── 导航与通用操作 ──────────────────────────────────────────────
  static const back = LucideIcons.arrowLeft;
  static const backChevron = LucideIcons.chevronLeft;
  static const chevronLeft = LucideIcons.chevronLeft;
  static const chevronRight = LucideIcons.chevronRight;
  static const chevronDown = LucideIcons.chevronDown;
  static const chevronUp = LucideIcons.chevronUp;
  static const arrowUp = LucideIcons.arrowUp;
  static const arrowDown = LucideIcons.arrowDown;
  static const close = LucideIcons.x;
  static const check = LucideIcons.check;
  static const add = LucideIcons.plus;
  static const addCircle = LucideIcons.plusCircle;
  static const search = LucideIcons.search;
  static const searchOff = LucideIcons.searchX;
  static const refresh = LucideIcons.refreshCw;
  static const moreHorizontal = LucideIcons.moreHorizontal;
  static const moreVertical = LucideIcons.moreVertical;
  static const delete = LucideIcons.trash2;
  static const clearAll = LucideIcons.listX;
  static const edit = LucideIcons.pencil;
  static const copy = LucideIcons.copy;
  static const share = LucideIcons.share2;
  static const download = LucideIcons.download;
  static const upload = LucideIcons.upload;
  static const sort = LucideIcons.arrowUpDown;
  static const settings = LucideIcons.settings;
  static const settingsSuggest = LucideIcons.settings2;
  static const tune = LucideIcons.slidersHorizontal;
  static const cancel = LucideIcons.xCircle;

  // ── 状态/反馈 ───────────────────────────────────────────────────
  static const checkCircle = LucideIcons.checkCircle2;
  static const checkSquare = LucideIcons.checkSquare;
  static const square = LucideIcons.square;
  static const radioChecked = LucideIcons.circleDot;
  static const radioUnchecked = LucideIcons.circle;
  static const info = LucideIcons.info;
  static const help = LucideIcons.helpCircle;
  static const warning = LucideIcons.alertTriangle;
  static const error = LucideIcons.alertCircle;
  static const visibility = LucideIcons.eye;
  static const visibilityOff = LucideIcons.eyeOff;
  static const lock = LucideIcons.lock;
  static const login = LucideIcons.logIn;
  static const logout = LucideIcons.logOut;
  static const timer = LucideIcons.timer;
  static const clock = LucideIcons.clock;
  static const verified = LucideIcons.badgeCheck;
  static const verifiedUser = LucideIcons.shieldCheck;
  static const swipe = LucideIcons.hand;
  static const lightbulb = LucideIcons.lightbulb;

  // ── 云服务/同步 ─────────────────────────────────────────────────
  static const cloud = LucideIcons.cloud;
  static const cloudQueue = LucideIcons.cloudy;
  static const cloudOff = LucideIcons.cloudOff;
  static const cloudDownload = LucideIcons.downloadCloud;
  static const cloudUpload = LucideIcons.uploadCloud;
  static const storage = LucideIcons.database;
  static const wifiFind = LucideIcons.wifi;
  static const backupRestore = LucideIcons.archiveRestore;
  // 云同步状态（0.257.0 无 cloudSync/cloudCheck，以 cloudCog/cloud 近似）
  static const cloudSync = LucideIcons.cloudCog;
  // 本地与云端数据不一致的 diff 标识
  static const syncDifferent = LucideIcons.diff;
  // 本地存储后端（无 phone_android 直译，以硬盘语义表达"本地"）
  static const localStorage = LucideIcons.hardDrive;

  // ── 人/账本/分类 ────────────────────────────────────────────────
  static const person = LucideIcons.user;
  static const people = LucideIcons.users;
  static const personAdd = LucideIcons.userPlus;
  static const personRemove = LucideIcons.userMinus;
  // 昵称/名片编辑入口
  static const nickname = LucideIcons.badge;
  static const book = LucideIcons.bookOpen;
  static const ledgerBook = LucideIcons.library;
  static const category = LucideIcons.shapes;
  static const receipt = LucideIcons.receipt;
  static const money = LucideIcons.banknote;
  static const currencyExchange = LucideIcons.arrowLeftRight;

  // ── 图表/分析 ───────────────────────────────────────────────────
  static const pieChart = LucideIcons.pieChart;
  static const barChart = LucideIcons.barChart3;
  static const autoAwesome = LucideIcons.sparkles;

  // ── 主题/外观 ───────────────────────────────────────────────────
  static const theme = LucideIcons.palette;
  static const themeAuto = LucideIcons.sunMoon;
  static const darkMode = LucideIcons.moon;
  static const lightMode = LucideIcons.sun;
  static const nightlight = LucideIcons.moonStar;
  static const twilight = LucideIcons.sunset;
  static const language = LucideIcons.languages;
  static const notifications = LucideIcons.bell;

  // ── 文件/数据 ───────────────────────────────────────────────────
  static const folder = LucideIcons.folder;
  static const folderShared = LucideIcons.share2;
  static const fileDownload = LucideIcons.fileDown;
  static const fileUpload = LucideIcons.fileUp;
  static const description = LucideIcons.fileText;
  static const article = LucideIcons.newspaper;
  static const checklist = LucideIcons.listChecks;
  static const driveFileMove = LucideIcons.folderSync;
  static const findInPage = LucideIcons.fileSearch;
  static const inbox = LucideIcons.inbox;
  // 配置导入导出等场景的"预览"区块标识
  static const preview = LucideIcons.eye;
  static const photoLibrary = LucideIcons.image;
  static const camera = LucideIcons.camera;
  static const qrCode = LucideIcons.qrCode;
  static const link = LucideIcons.link;

  // ── 日历 ────────────────────────────────────────────────────────
  static const calendar = LucideIcons.calendar;
  static const calendarToday = LucideIcons.calendarCheck;
  static const calendarMonth = LucideIcons.calendarDays;
  static const calendarViewMonth = LucideIcons.calendarCheck2;
  static const calendarViewWeek = LucideIcons.calendarRange;
  static const viewWeek = LucideIcons.layoutGrid;

  // ── 安全/锁屏 ───────────────────────────────────────────────────
  static const dialpad = LucideIcons.grid;
  static const fingerprint = LucideIcons.fingerprint;
  static const backspace = LucideIcons.delete;
  static const keyboardReturn = LucideIcons.cornerDownLeft;

  // ── 杂项 ────────────────────────────────────────────────────────
  static const bugReport = LucideIcons.bug;
  static const cleaning = LucideIcons.sprayCan;
  static const repeat = LucideIcons.repeat;

  // ── 分类编辑页 ──────────────────────────────────────────────────
  // chart-column 在 lucide_icons 0.257.0 中不存在，barChart3 为其等效图标（竖向柱状图）
  static const categoryDetail = LucideIcons.barChart3;
  static const parentCategory = LucideIcons.arrowUp;
}
