unit comm_data;

interface

uses Windows, SysUtils;

type
  TUser = record
    Name : string;
    IP   : string;
    sex  : DWord;
  end;
  TUsers = array of TUser;

  TChannel = record
    Name  : string;
    Users : DWord;
    Theme : string;
  end;
  TChannels = array of TChannel;

  TRegUser = record
    Name : string;
    IP   : string;
  end;
  TRegUsers = array of TRegUser;

  TWaitUser = record
    Status: Word;
    Name  : string;
    IP    : string;
    ID    : string;
    date  : Double;
    msg   : string;
    moder : string;
    reason: string;
  end;
  TWaitUsers = array of TWaitUser;

  TRestriction = record
    restID : DWORD;
    date   : Double;
    remain : Double;
    ident  : DWord;
    Name   : string;
    IP     : string;
    IPrange: string;
    compID : string;
    banType: DWord;
    channel: string;
    moder  : string;
    reason : string;
  end;
  TRestrictions = array of TRestriction;

  TtypeCommFortProcess = procedure(dwPluginID : DWORD; dwMessageID : DWORD; bMessage : PChar; dwMessageLength : DWORD); stdcall;
  TtypeCommFortGetData = function(dwPluginID : DWORD; dwMessageID : DWORD; bInBuffer : TBytes; inBufferLength : DWORD; bOutBuffer : PChar; outBufferLength : DWORD) : DWORD; stdcall;
  TError = procedure(Sender: TObject; Error: Exception; Extratext: String='') of object;
  TPreMsg = function(Sender: TObject; bMessage : PCHAR; dwMessageLength : PDWORD): boolean of object;
  TAuthFail = procedure(Sender: TObject; Name : string; Reason: Word) of object;
  TJoinChannelFail = procedure(Sender: TObject; Name, Channel : string; Reason: Word) of object;
  TPrivMsg = procedure(Sender: TObject; Name: String; User : TUser; regime : integer; bMessage : string) of object;
  TPMsg = procedure(Sender: TObject; Name: String; User : TUser; bMessage : string) of object;
  TJoinBot = procedure(Sender: TObject; Name: string; channel : string; theme : string; greeting: string) of object;
  TPubMsg = procedure(Sender: TObject; Name: String; User : TUser; channel: string; regime : integer; bMessage : string) of object;
  TChnTheme = procedure(Sender: TObject; Name: String; User : TUser; channel: string; newtheme : string) of object;
  TUsrJoin = procedure(Sender: TObject; Name: String; User : TUser; channel: string) of object;
  TUsrLeft = procedure(Sender: TObject; Name: String; User : TUser; channel: string) of object;
  TChnName = procedure(Sender: TObject; User : TUser; newname: string; newicon: integer) of object;
  TChnIcon = procedure(Sender: TObject; User : TUser; newicon: integer) of object;
  TChnStt = procedure(Sender: TObject; User : TUser; newstate: string) of object;
  TChatUsrJoin = procedure(Sender: TObject; User : TUser) of object;
  TChatUsrLeft = procedure(Sender: TObject; User : TUser) of object;
  TonConStChg =  procedure(Sender: TObject; newstate : DWord) of object;

const

  PM_PLUGIN_JOIN_VIRTUAL_USER   = 1001; //plugin -> commfort: Подключить виртуального пользователя: текст(имя) + текст(IP-адрес) + число(тип пароля) + текст(пароль) + число(иконка)
  PM_PLUGIN_LEAVE_VIRTUAL_USER  = 1002; //plugin -> commfort: Отключить виртуального пользователя: текст(имя)
  PM_PLUGIN_SNDMSG_PUB          = 1020; //plugin -> commfort: Опубликовать сообщение в канал: текст(имя виртуального пользователя) + число(режим) + текст(канал) + текст(сообщение) Режимы: 0 - текст опубликован обычно 1 - текст опубликован состоянием (F9)
  PM_PLUGIN_SNDMSG_PRIV         = 1021; //plugin -> commfort: Опубликовать сообщение в приват: текст(имя виртуального пользователя) + Число(режим)+текст(имя пользователя)+текст(сообщение) Режимы: 0 - текст опубликован обычно 1 - текст опубликован состоянием (F9)
  PM_PLUGIN_SNDMSG_PM           = 1022; //plugin -> commfort: Отправить личное сообщение:  текст(имя виртуального пользователя) + число(тип важности) + текст(имя пользователя)+текст(сообщение)
  PM_PLUGIN_THEME_CHANGE        = 1023; //plugin -> commfort: Изменить тему канала: текст(имя виртуального пользователя) + Текст(канал)+текст(новая тема)
  PM_PLUGIN_GREETING_CHANGE     = 1024; //plugin -> commfort: Изменить приветствие канала: Текст(канал)+текст(новое приветствие)
  PM_PLUGIN_SNDIMG_PUB          = 1080; //plugin -> commfort: Опубликовать изображение в канал: текст(имя виртуального пользователя) + текст(канал) + данные(данные изображения в формате jpg)
  PM_PLUGIN_SNDIMG_PRIV         = 1081; //plugin -> commfort: Опубликовать изображение в приват: текст(имя виртуального пользователя) + текст(имя пользователя) + данные(данные изображения в формате jpg)


  PM_PLUGIN_STATUS_CHANGE       = 1025; //plugin -> commfort: Изменить состояние: текст(имя виртуального пользователя) + текст(новое состояние)
  PM_PLUGIN_RENAME_CHANNEL      = 1029; //plugin -> commfort: Переимновать канал : текст(имя виртуального пользователя) + текст(канал) + текст(новое название канала)

  PM_PLUGIN_RESTRICT_SET        = 1040; //plugin -> commfort: Наложить ограничение: текст(имя виртуального пользователя) + число(тип идентификации) + текст(объект идентификации) + число (тип ограничения) + текст(канал ограничения) + срок() + текст(причина ограничения) + число(тип анонимности)
  PM_PLUGIN_RESTRICT_DEL        = 1041; //plugin -> commfort: Снять ограничение: текст(имя виртуального пользователя) + число(ID ограничения) + текст(причина)
  PM_PLUGIN_CHANNEL_DEL         = 1028; //plugin -> commfort: Удалить (закрыть) канал: текст(имя виртуального пользователя) + текст(канал)
  PM_PLUGIN_CHANGE_ICON         = 1026; //plugin -> commfort: Изменить иконку: текст(имя виртуального пользователя) + число(новая иконка)
  PM_PLUGIN_ANNOUNCMENT_ADD     = 1050; //plugin -> commfort: Опубликовать объявление: текст(имя виртуального пользователя) + число(ID раздела) + текст(заголовок) + текст(текст объявления) + число(тип важности) + число(тип запрета комментариев) + срок(срок действия объявления)
  PM_PLUGIN_ANNOUNCMENT_DEL     = 1051; //plugin -> commfort: Удалить объявление: текст(имя виртуального пользователя) + число(ID объявления)
  PM_PLUGIN_COMMENT_ADD         = 1055; //plugin -> commfort: Опубликовать комментарий: текст(имя виртуального пользователя) + число(ID объявления) + текст(текст комментария)
  PM_PLUGIN_COMMENT_DEL         = 1056; //plugin -> commfort: Удалить комментарий: текст(имя виртуального пользователя) + число(ID комментария)
  PM_PLUGIN_PASSWORD_CHANGE     = 1070; //plugin -> commfort: Изменить пароль: текст(имя виртуального пользователя) + текст(имя пользователя, которму необходимо изменить пароль) + число(тип пароля) + текст(новый пароль)
  PM_PLUGIN_ACCOUNT_DEL         = 1071; //plugin -> commfort: Удалить учетную запись с сервера : текст(имя виртуального пользователя) + текст(имя удаляемого пользователя)
  PM_PLUGIN_ACCOUNT_AGREE       = 1033; //plugin -> commfort: Принять активацию учетной записи: текст(имя виртуального пользователя) + текст(принимаемая учетная запись)
  PM_PLUGIN_ACCOUNT_DISAGREE    = 1034; //plugin -> commfort: Отклонить активацию учетной записи: текст(имя виртуального пользователя) + текст(отклоняемая учетная запись) + текст(причина)

  PM_PLUGIN_STOP                = 2100; //plugin -> commfort: Остановить плагин
  PM_PLUGIN_CHANNEL_JOIN        = 1026; //plugin -> commfort: Создать/подключиться к общему каналу: текст(имя виртуального пользователя) + Текст(канал)+число(видимость)+число(режим входа) Видимость: 0 - канал невидим в списке каналов 1 - канал доступен в списке каналов Режим входа: 0 - вход разрешен всем пользователям 1 - вход разрешен только по приглашению Внимание! Один пользователь может одновременно находиться не более чем в 16 общих каналах.
  PM_PLUGIN_CHANNEL_LEAVE       = 1027; //plugin -> commfort: Покинуть общий канал

  PM_PLUGIN_AUTH_FAIL           = 1090; //commfort -> plugin: Авторизация виртуального пользователя невозможна: текст(имя виртуального пользователя) + число(код причины)
  PM_PLUGIN_JOINCHANNEL_FAIL    = 1091; //commfort -> plugin: Подключение к каналу виртуального пользователя невозможно:текст(имя виртуального пользователя) + текст(канал) + число(код причины)
  PM_PLUGIN_MSG_PRIV            = 1060; //commfort -> plugin: Сообщение в приват: текст(имя виртуального пользователя) + пользователь()+число(режим)+текст(сообщение) Режимы: 0 - текст опубликован обычно 1 - текст опубликован состоянием (F9)
  PM_PLUGIN_MSG_PM              = 1061; //commfort -> plugin: Личное сообщение: текст(имя виртуального пользователя) + пользователь()+текст(сообщение)
  PM_PLUGIN_JOIN_BOT            = 1062; //commfort -> plugin: Подключение к каналу бота: текст(имя виртуального пользователя) + текст(канал)+текст(тема)+текст(приветствие)
  PM_PLUGIN_MSG_PUB             = 1070; //commfort -> plugin: Публикация сообщения в канал: текст(имя виртуального пользователя) + пользователь()+текст(канал)+число(режим)+текст(сообщение) Режимы: 0 - текст опубликован обычно 1 - текст опубликован состоянием (F9)
  PM_PLUGIN_THEME_CHANGED       = 1071; //commfort -> plugin: Смена темы канала: текст(имя виртуального пользователя, который присутствует в данном канале) + пользователь()+текст(канал)+текст(новая тема)
  PM_PLUGIN_USER_JOINEDCHANNEL  = 1072; //commfort -> plugin: Подключение к каналу другого пользователя: текст(имя виртуального пользователя, который присутствует в данном канале) + пользователь()+текст(канал)
  PM_PLUGIN_USER_LEAVEDCHANNEL  = 1073; //commfort -> plugin: Выход из канала другого пользователя: текст(имя виртуального пользователя, который присутствует в данном канале) + пользователь()+текст(канал)
  PM_PLUGIN_ICON_CHANGED        = 1076; //commfort -> plugin: Смена иконки: Пользователь()+число(номер новой иконки)
  PM_PLUGIN_STATUS_CHANGED      = 1077; //commfort -> plugin: Смена состояния: Пользователь()+текст(новое состояние)
  PM_PLUGIN_USER_JOINED         = 1078; //commfort -> plugin: Пользователь присоединился к чату: Пользователь()
  PM_PLUGIN_USER_LEAVED         = 1079; //commfort -> plugin: Пользователь покинул чат: Пользователь()

  GD_PROGRAM_TYPE               = 2000; //plugin -> commfort: Тип программы. Блок данных (исходящий): [нулевое значение]. Блок данных (входящий): число(тип программы)
  GD_PROGRAM_VERSION            = 2001; //plugin -> commfort: Версия программы. Блок данных (исходящий): [нулевое значение]. Блок данных (входящий): текст(версия программы)
  GD_PLUGIN_TEMPPATH            = 2010; //plugin -> commfort: Рекомендуемый путь для временных файлов плагинов. Блок данных (исходящий): [нулевое значение]. Блок данных (входящий): текст(путь)
  GD_MAXIMAGESIZE               = 1030; //plugin -> commfort: Максимальный размер изображения в канале. Блок данных (исходящий): [нулевое значение]. Блок данных (входящий): число(количество) + (текст(название канала) + число(количество пользователей в канале) + текст(тема канала))*количество
  GD_CHANNELS_GET               = 1040; //plugin -> commfort: Список общих каналов. Блок данных (исходящий): текст(название канала). Блок данных (входящий): число(максимальный объем в байтах) + число(максимальный размер в пикселах)
  GD_USERS_GET                  = 1041; //plugin -> commfort: Список пользователей в чате. Блок данных (исходящий): [нулевое значение]. Блок данных (входящий): число(количество) + пользователь()*количество
  GD_USERCHANNELS_GET           = 1080; //plugin -> commfort: Список каналов, к которым подключен виртуальный пользователь. Блок данных (исходящий): текст(имя виртуального пользователя). Блок данных (входящий): число(количество) + (текст(название канала) + число(количество пользователей в канале) + текст(тема канала))*количество
  GD_CHANNELUSERS_GET           = 1081; //plugin -> commfort: Список пользователей в канале, к которому подключен виртуальный пользователь. Блок данных (исходящий): текст(имя виртуального пользователя) + текст(канал). Блок данных (входящий): число(количество) + пользователь()*количество
  GD_REGUSERS_GET               = 1042; //plugin -> commfort: Список зарегистрированных пользователей. Блок данных (исходящий): [нулевое значение]. Блок данных (входящий): число(количество) + пользователь()*количество
  GD_WAITUSERS_GET              = 1043; //plugin -> commfort: Список заявок на активацию. Блок данных (исходящий): [нулевое значение]. Блок данных (входящий): число(количество) + (число(статус) + дата_и_время() + текст(имя) + текст(IP-адрес) + текст(ID компьютера) + текст(сообщение) + текст(учетная запись модератора, обработавшего заявку) + текст(причина отклонения))*количество
  GD_RESTRICTIONS_GET           = 1044; //plugin -> commfort: Список ограничений. Блок данных (исходящий): [нулевое значение]. Блок данных (входящий): число(количество) + (число(ID ограничения) + дата_и_время(создания записи) + срок(оставшийся до истечения ограничения) + число(тип идентификации) + текст(учетная запись) + текст(IP-адрес) + текст(диапазон IP-адресов) + текст(ID компьютера) + число(тип ограничения) + текст(канал) + текст(учетная запись модератора) + текст(причина))*количество
  GD_IPSTATE_GET                = 1050; //plugin -> commfort: Состояние скрытия IP-адреса. Блок данных (исходящий): текст(имя пользователя). Блок данных (входящий): число(состояние скрытия IP-адреса)
  GD_PASSWORD_GET               = 1060; //plugin -> commfort: Пароль учетной записи. Блок данных (исходящий): текст(имя пользователя). Блок данных (входящий): текст(32 символьный MD5 хэш-код пароля)
  GD_IP_GET                     = 1061; //plugin -> commfort: IP-адрес пользователя. Блок данных (исходящий): текст(имя пользователя). Блок данных (входящий): текст(IP-адрес)
  GD_ID_GET                     = 1062; //plugin -> commfort: ID компьютера пользователя. Блок данных (исходящий): текст(имя пользователя). Блок данных (входящий): текст(ID компьютера)

  GD_PLUGIN_SERVER_OR_CLIENT    = 2800; //plugin -> commfort: Предназначение плагина
  GD_PLUGIN_NAME                = 2810; //plugin -> commfort: Название плагина

  PRE_PLUGIN_MSG                = 0;  //commfort -> plugin: Премодерация сообщений
  PRE_PLUGIN_THEME              = 1;  //commfort -> plugin: Премодерация тем
  PRE_PLUGIN_ANNOUNCMENT        = 2;  //commfort -> plugin: Премодерация объявлений

  PM_CLIENT_SNDMSG_PUB          = 50;
  PM_CLIENT_SNDMSG_PRIV         = 63;
  PM_CLIENT_SNDMSG_PM           = 70;
  PM_CLIENT_THEME_CHANGE        = 61;
  PM_CLIENT_GREETING_CHANGE     = 62;
  PM_CLIENT_SNDIMG_PUB          = 51; // plugin -> commfort: Отправить изображение в общий канал. текст(название канала) + число(формат изображения) + данные(данные изображения). Форматы: 0 - bmp, 1 - jpg, 2 - bmp.
  PM_CLIENT_SNDIMG_PRIV         = 64; //plugin -> commfort: Отправить изображение в приват. текст(имя пользователя) + число(формат изображения) + данные(данные изображения). Форматы: 0 - bmp, 1 - jpg, 2 - bmp.
  PM_CLIENT_CHANNEL_JOIN        = 67;
  PM_CLIENT_CHANNEL_LEAVE       = 66; //plugin -> commfort: Покинуть общий канал
  PM_CLIENT_PRIVATE_LEAVE       = 65; //plugin -> commfort: Покинуть приватный канал

  PM_CLIENT_CONSTATUS_CHANGED   = 3; //commfort -> plugin: Связь с сервером (данный клиент): число(новое состояние связи с сервером)
  PM_CLIENT_MSG_PUB             = 5; //commfort -> plugin: Публикация сообщения в канал: пользователь()+текст(канал)+число(режим)+текст(сообщение) Режимы: 0 - текст опубликован обычно 1 - текст опубликован состоянием (F9)
  PM_CLIENT_MSG_PRIV            = 10;//commfort -> plugin: Сообщение в приват: пользователь()+число(режим)+текст(сообщение) Режимы: 0 - текст опубликован обычно 1 - текст опубликован состоянием (F9) 2 - изображение в приватный канал (текст в этом случае будет "[image]") 3 - личное сообщение

  GD_CLIENT_CURRENT_USER_GET    = 12; //plugin -> commfort: Текущий пользователь. Блок данных (исходящий): [нулевое значение]. Блок данных (входящий): пользователь(текущий пользователь)
  GD_CLIENT_CONSTATE_GET        = 11; //plugin -> commfort: Состояние связи с сервером.
  GD_CLIENT_RIGHT_GET           = 19; //plugin -> commfort: Права текущей учетной записи. Блок данных (исходящий): число(вид права) + текст(канал). Блок данных (входящий): число(тип активности права)
  GD_CLIENT_CHANNELUSERS_GET    = 17; //plugin -> commfort: Список пользователей в канале. Блок данных (исходящий): текст(канал). Блок данных (входящий): число(количество) + пользователь()*количество

  MAX_NAME = 30;

  PLU_VER  = '3.6.0';

  PLU_NAME = 'Мафия (игра) '+PLU_VER;

var
  msg_format_begin, msg_format_end: String;
  msg_send_type: Byte;
  BOT_NAME: String;
  BOT_PASS: String;
  BOT_ISFEMALE: Byte;
  BOT_IP: String;
  PROG_TYPE:Byte;

  // Пути к файлам
  config_dir: String;

  file_config: String;
  file_messages: String;
  file_gametypes: String;
  file_users: String;
  file_data: String;
  file_log: String;
  file_template: String;
  file_template_greeting: String;

  file_export_stats:String;

implementation

end.
