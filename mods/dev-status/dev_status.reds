// dev-status: a few seconds after every save load, re-send each sideloaded dev mod's
// message in the conversation contacts/unknown/devstatus. Dev mods add their message to that
// conversation in their own journal (see tools/devstatus.py).
module DevStatus

public class DevStatusAnnounce extends DelayCallback {
  public let game: GameInstance;

  public func Call() -> Void {
    let journal = GameInstance.GetJournalManager(this.game);
    let chat = journal.GetEntryByString("contacts/unknown/devstatus", "gameJournalPhoneConversation");
    if !IsDefined(chat) {
      return;
    }
    let all: JournalRequestStateFilter;
    all.inactive = true;
    all.active = true;
    all.succeeded = true;
    all.failed = true;
    let messages: array<wref<JournalEntry>>;
    journal.GetChildren(chat, all, messages);
    Resend(journal, chat, JournalNotifyOption.DoNotNotify);
    for message in messages {
      Resend(journal, message, JournalNotifyOption.Notify);
    }
  }
}

// Inactive first: activating an already active entry sends no notification.
func Resend(journal: ref<JournalManager>, entry: wref<JournalEntry>, notify: JournalNotifyOption) {
  let hash = Cast<Uint32>(journal.GetEntryHash(entry));
  journal.ChangeEntryStateByHash(hash, gameJournalEntryState.Inactive, JournalNotifyOption.DoNotNotify);
  journal.ChangeEntryStateByHash(hash, gameJournalEntryState.Active, notify);
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  let announce = new DevStatusAnnounce();
  announce.game = this.GetGame();
  GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(announce, 5.0, false);
  return result;
}
