unit mafia_data;

interface

uses
    Classes, SyncObjs;

const
    TopMaxPlayers = 20;

    setRoles: set of 1..255 = [1..9, 51, 101..104, 151, 201..203];

type
  MafUser = record
    id: Word;
    name: String;
    IP: String;
    compID: String;
    pol: integer;
    plays : Word;
    points : Integer;
    wins : Word;
    draws : Word;
    rate : String;
    gamepoints: Integer;
    died: Byte;
    delayedDeath: Byte;
    gamestate: byte;
    {Статус игрока
      0: Труп
      1: Мирный
      2: Комиссар
      3: Путана
      4: Судья
      5: Доктор
      6: Старейшина
      7: Горец
      8: Шериф
      9: Бомж
      51: Сержант

      101: Мафф
      102: Киллер
      103: Адвокат
      104: Подрывник

      151: Якудза

      201: Маньяк
      202: Робин Гуд
      203: Грабитель
    }
    gamestate_start: byte;
    activity: Byte;
    {Действовал ли, и против кого}
    activity2: Byte;
    {Для тех, кто действует днем + горец}
    night_place: Byte;
    {выбранное место (если совпадет с выбранным местом проводника, то... БУМ)}
    lastactivity: Byte;
    {Последнее действие(чтобы нельзя было 2 раза подряд к одному и тому же)}
    voting: ShortInt;
    {Голосование вечером}
    use_mask: Byte;
    {
      0:Не использовал
      1:На этом ходу
      2:Использована в игре(запрет покупки)
    }

    use_radio: Byte;
    {
      0:Не использовано
      1:Использована в игре(запрет покупки)
      2 и более: Действует
    }

    no_activity_days: Byte;
    {Количество дней до убийства игрока за бездействие на дневных голосованиях}

  end;

  PMafUser = ^MafUser;
  TwoByte = array[0..1] of Byte;

  TRoleText = array[0..255, 0..3] of String;

var
  // Игровые настройки
  game_chan : String;
  help_chan : String;
  main_chan : array[1..8] of String;
  mask_price : Word;
  radio_price : Word;
  radio_nights: Word;

  fast_game: Boolean;

  time_start : Word;
  time_night : Word;
  time_morning : Word;
  time_day : Word;
  time_evening : Word;
  time_accept: Word;
  time_pause: Word;
  time_ban: Double;

  ip_filter, id_filter: Boolean;
  start_night: Boolean;
  show_night_actions: Boolean;
  ban_on_death, ban_private_on_death: Boolean;
  stat_to_private: Boolean;
  top_default: Byte;
  ban_reason, ban_private_reason, unban_reason: String;
  topic_play, topic_wait, topic_playergetting: String;
  load_settings_on_start, export_stats, update_greeting: Boolean;
  changegametype_notify: Byte;
  changegametype_games, changegametype_current_games: Byte;
  show_votepoints: Boolean;
  kill_for_no_activity: Byte;

  Gametype: record
    Name: String;
    MinPlayers, PlayersForSpecialMaf, PlayersForNeutral, RandomHelpers: Byte;
    MafCount: Single;
    UseYakuza, UseNeutral, UseSpecialMaf, UseShop, ComKillManiac: Boolean;
    ManiacCanUseCurse: Boolean;
    ShowRolesOnStart, NeutralCanWin, InstantCheck, ShowNightComments: Boolean;
    InfectionChance: Byte;
    ComType: Byte;
    UseRole: array [3..255] of Byte;
    RoleMinPlayers: array [3..99] of Byte;
    RoleKnowCom: array [3..99] of Boolean;
  end;

  points_cost: array [1..255] of Integer;

  State : Byte; { Состояние мафии
    0 : Выключена
    1 : Набор игроков
    2 : Ночь
    3 : Обсуждение
    4 : День
    5 : Вечер
    255 : Промежуточное
  }

  maf_state, y_state: Byte;
  {
    1 - сходил хоть один из мафов
  }
  maf_phrase, y_phrase: String;

  //--------------------------------------
  com_state: byte;
  {
    0: Труп
    1: Бездействие
    2: Против мирного
    3: Против мафа
    4: Против маньяка
    5: Против любого, команда !подстрелить
  }

  com_target: byte;   //Цель комиссара
  com_player: byte;   //Сам комиссар
  com_phrase: String;
  //--------------------------------------

  //--------------------------------------
  putana_state: byte;
  {
    0: Труп/не в игре
    1: Бездействие
    2: Действовала
  }

  putana_target: byte;   //Цель путаны
  putana_player: byte;   //Сама путана
  putana_phrase: String;
  //--------------------------------------

  //--------------------------------------
  judge_state: byte;
  {
    0: Труп/не в игре
    1: Бездействие
    2: Оправдывает
  }

  judge_target: byte;   //Цель судьи
  judge_player: byte;   //Сам судья
  judge_phrase: String;
  //--------------------------------------

  //--------------------------------------
  serj_player: byte;   //Сам сержант
  //--------------------------------------

  //--------------------------------------
  doctor_state: byte;
  {
    0: Труп/не в игре
    1: Бездействие
    2: Лечит
  }

  doctor_target: byte;   //Цель дока
  doctor_player: byte;   //Сам док
  doctor_heals_himself: byte; //Лечил ли док себя
  //--------------------------------------

  //--------------------------------------
  highlander_phrase: String;
  highlander_under_attack: Boolean;
  //--------------------------------------

  //--------------------------------------
  sherif_state: byte;
  {
    0: Труп/не в игре
    1: Бездействие
    2: Выстрел
    3: Против горца
  }

  sherif_target: byte;   //Цель шерифа
  sherif_player: byte;   //Сам шериф
  sherif_phrase: String;
  //--------------------------------------

  //--------------------------------------
  homeless_state: byte;
  {
    0: Труп/не в игре
    1: Бездействие
    2: Проверяет
  }

  homeless_target: byte;   //Цель бомжа
  homeless_player: byte;   //Сам бомж
  homeless_phrase: String;
  //--------------------------------------

  //--------------------------------------
  killer_state: byte;
  {
    0: Труп/не в игре
    1: Бездействие
    2: Против смертного игрока
    3: Против горца
  }

  killer_target: byte;   //Цель киллера
  killer_player: byte;   //Сам киллер
  killer_phrase: String;
  //--------------------------------------

  //--------------------------------------
  lawyer_state: byte;
  {
    0: Труп/не в игре
    1: Бездействие
    2: Проверяет
  }

  lawyer_target: byte;   //Цель адвоката
  lawyer_player: byte;   //Сам адвокат
  //--------------------------------------

  //--------------------------------------
  podrivnik_state: byte;
  {
    0: Труп/не в игре
    1-3: Бездействие
    4: БУМ
  }

  podrivnik_target: byte;   //Цель подрывника
  podrivnik_player: byte;   //Сам подрывник
  podrivnik_phrase: String;
  //--------------------------------------

  //--------------------------------------
  maniac_state: byte;
  {
    0: Труп/не в игре
    1: Бездействие
    2: Против смертного игрока
    3: Против горца
    10: Проклятье
  }

  maniac_target: byte;   //Цель маньяка
  maniac_player: byte;   //Сам маньяк
  maniac_use_curse: byte; // Использовал ли проклятье
  maniac_phrase: String;
  //--------------------------------------

  //--------------------------------------
  robin_state: byte;
  {
    0: Труп/не в игре
    1: Бездействие
    2: На мирного
    3: На особенного
  }

  robin_target: byte;   //Цель Робин Гуда
  robin_player: byte;   //Сам Робин Гуд
  robin_phrase: String;
  //--------------------------------------

  //--------------------------------------
  robber_state: byte;
  {
    0: Труп/не в игре
    1: Бездействие
    2: Действует
  }

  robber_target: byte;   //Цель грабителя
  robber_player: byte;   //Сам грабитель
  robber_phrase: String;
  //--------------------------------------

  maf_chan: String;     //Логово
  y_chan: String;     //Логово

  maf_ingame: Byte;

  get_state: Byte;      //Статус набора игроков
  night_state: Byte;    //Статус ночи (при последовательных ходах ролей)

  TopPoints : array [1..TopMaxPlayers] of record
    Name: String;
    Points: Integer;
  end;
  TopRate : array [1..TopMaxPlayers] of record
    Name: String;
    Rate: Single;
  end;
  TopRole : array [1..255] of record
    Name: String;
    Plays: Integer;
  end;

  NightPlaces: array [0..2] of String;

  UpdateTopCriticalSection: TCriticalSection;

  Messages: TStringList;

implementation

end.
