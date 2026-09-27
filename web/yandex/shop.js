/* Browser modal stays responsive while Godot is paused for the shop/payment UI. */
(function () {
  'use strict';
  const translations = {
    en: ['Shop', 'Close', 'Buy', 'Checking purchases…', 'Purchases are unavailable. Please try again.', 'Try again', 'Purchase restored or completed.', 'Payment was cancelled or could not be completed. Any pending purchase will be recovered automatically.', 'All these levels are already unlocked.', 'Your account changed. Reload to restore its purchases.', 'Reload', 'Purchased skips'],
    ru: ['Магазин', 'Закрыть', 'Купить', 'Проверяем покупки…', 'Покупки недоступны. Попробуйте ещё раз.', 'Повторить', 'Покупка восстановлена или завершена.', 'Оплата отменена или не завершена. Необработанная покупка будет восстановлена автоматически.', 'Все эти уровни уже открыты.', 'Аккаунт изменился. Перезагрузите игру для восстановления покупок.', 'Перезагрузить', 'Купленные пропуски'],
    de: ['Shop', 'Schließen', 'Kaufen', 'Käufe werden geprüft…', 'Käufe sind nicht verfügbar. Bitte erneut versuchen.', 'Erneut versuchen', 'Kauf wiederhergestellt oder abgeschlossen.', 'Zahlung abgebrochen oder fehlgeschlagen. Ausstehende Käufe werden automatisch wiederhergestellt.', 'Alle diese Level sind bereits freigeschaltet.', 'Dein Konto hat sich geändert. Lade das Spiel neu, um Käufe wiederherzustellen.', 'Neu laden', 'Gekaufte Level-Sprünge'],
    es: ['Tienda', 'Cerrar', 'Comprar', 'Comprobando compras…', 'Las compras no están disponibles. Inténtalo de nuevo.', 'Reintentar', 'Compra restaurada o completada.', 'El pago se canceló o no se completó. Las compras pendientes se recuperarán automáticamente.', 'Todos estos niveles ya están desbloqueados.', 'Tu cuenta ha cambiado. Recarga para restaurar sus compras.', 'Recargar', 'Saltos comprados'],
    fr: ['Boutique', 'Fermer', 'Acheter', 'Vérification des achats…', 'Les achats sont indisponibles. Réessayez.', 'Réessayer', 'Achat restauré ou terminé.', 'Le paiement a été annulé ou a échoué. Tout achat en attente sera restauré automatiquement.', 'Tous ces niveaux sont déjà débloqués.', 'Votre compte a changé. Rechargez le jeu pour restaurer ses achats.', 'Recharger', 'Passages achetés'],
    pt_BR: ['Loja', 'Fechar', 'Comprar', 'Verificando compras…', 'As compras estão indisponíveis. Tente novamente.', 'Tentar novamente', 'Compra restaurada ou concluída.', 'O pagamento foi cancelado ou não foi concluído. Compras pendentes serão recuperadas automaticamente.', 'Todas essas fases já estão desbloqueadas.', 'Sua conta mudou. Recarregue para restaurar as compras.', 'Recarregar', 'Pulos comprados'],
    tr: ['Mağaza', 'Kapat', 'Satın al', 'Satın alımlar kontrol ediliyor…', 'Satın alımlar kullanılamıyor. Lütfen tekrar dene.', 'Tekrar dene', 'Satın alım geri yüklendi veya tamamlandı.', 'Ödeme iptal edildi veya tamamlanamadı. Bekleyen satın alımlar otomatik olarak geri yüklenecek.', 'Bu bölümlerin tümü zaten açık.', 'Hesabın değişti. Satın alımları geri yüklemek için oyunu yeniden yükle.', 'Yeniden yükle', 'Satın alınan atlama hakları']
  };
  let dialog, list, status, close, requested = [], message = '', loading = false;
  const api = window.PairUpPurchases;
  function text() {
    const lang = (window.mergeYandexLanguage || 'en').replace('-', '_');
    return translations[lang.startsWith('pt') ? 'pt_BR' : lang.split('_')[0]] || translations.en;
  }
  function element(tag, content, parent) {
    const node = document.createElement(tag);
    if (content) node.textContent = content;
    if (parent) parent.appendChild(node);
    return node;
  }
  function button(label, parent, action) {
    const node = element('button', label, parent); node.type = 'button'; node.onclick = action; return node;
  }
  function render() {
    if (!dialog) return;
    const state = JSON.parse(api.snapshot()), t = text();
    close.disabled = state.paying;
    status.textContent = loading || state.busy ? t[3] : state.error === 'account_changed' ? t[9] : state.error ? t[4] : message;
    if (loading || state.busy) {
      // Keep an already rendered shop stable during checkout or background refresh.
      for (const button of list.querySelectorAll('button')) button.disabled = true;
      return;
    }
    list.replaceChildren();
    if (!state.ready) {
      if (!state.busy) button(state.error === 'account_changed' ? t[10] : t[5], list, () => {
        if (state.error === 'account_changed') window.location.reload();
        else api.refresh();
      });
      return;
    }
    element('p', `${t[11]}: ${state.paid_skips}`, list);
    const products = state.catalog.filter(p => requested.includes(p.id) &&
      !state.owned.includes(p.id) && !state.owned.includes('unlock_all_levels'));
    if (!products.length) element('p', t[8], list);
    for (const product of products) {
      const card = element('article', '', list);
      const icon = element('img', '', card);
      icon.src = `purchase-icons/${product.id === 'skips_5' ? 'skips_5' : product.id === 'unlock_all_levels' ? 'unlock_all' : 'unlock_world'}.png`;
      icon.alt = ''; icon.width = 88; icon.height = 88;
      element('h3', product.title, card);
      element('p', product.description, card);
      const buy = button('', card, async () => {
        message = '';
        const result = await api.buy(product.id);
        message = result.ok ? t[6] : result.error === 'cancelled' ? t[7] : t[4];
        render();
      });
      buy.disabled = state.busy;
      element('span', `${t[2]} — ${product.price}`, buy);
      if (product.currencyImage) {
        const currency = element('img', '', buy);
        currency.src = product.currencyImage; currency.alt = ''; currency.width = 24; currency.height = 24;
      }
    }
  }
  function hide() {
    if (JSON.parse(api.snapshot()).paying) return;
    dialog.remove(); dialog = null;
    api.setModal(false);
    GodotYandexBridge.refocusCanvas();
  }
  api.openShop = function (idsJson) {
    if (dialog) return;
    requested = JSON.parse(idsJson); message = ''; loading = true;
    if (!document.getElementById('pair-up-shop-style')) {
      const style = element('style', '', document.head); style.id = 'pair-up-shop-style';
      style.textContent = `#pair-up-shop{position:fixed;inset:0;z-index:10000;background:#020c13dc;display:flex;align-items:center;justify-content:center;padding:16px;box-sizing:border-box;font:17px/1.45 system-ui,sans-serif;color:#f5f3df;touch-action:pan-y}#pair-up-shop *{box-sizing:border-box}#pair-up-shop section{width:480px;max-width:100%;max-height:100%;overflow:auto;background:#092c32;border:3px solid #ac955b;border-radius:20px;padding:20px;box-shadow:0 12px 60px #000}#pair-up-shop header{display:flex;align-items:center;justify-content:space-between;gap:12px}#pair-up-shop h2{margin:0;color:#ffda76;font-size:28px}#pair-up-shop h3{font-size:20px;margin:0 0 8px}#pair-up-shop p{margin:10px 0}#pair-up-shop article{border-top:1px solid #678075;padding:18px 0;display:flow-root}#pair-up-shop article>img{float:left;margin:0 14px 8px 0;border-radius:12px}#pair-up-shop button{font:inherit;background:#155059;color:#fff5d5;border:1px solid #bea55e;border-radius:10px;min-height:44px;padding:9px 16px;cursor:pointer;white-space:normal}#pair-up-shop article button{display:flex;align-items:center;justify-content:center;gap:6px;width:100%;clear:both}#pair-up-shop button:disabled{opacity:.5;cursor:wait}#pair-up-shop button:focus-visible{outline:3px solid #ffe09b;outline-offset:3px}`;
    }
    dialog = element('div', '', document.body); dialog.id = 'pair-up-shop';
    const panel = element('section', '', dialog); panel.setAttribute('role', 'dialog'); panel.setAttribute('aria-modal', 'true');
    panel.setAttribute('aria-label', text()[0]);
    const header = element('header', '', panel); element('h2', text()[0], header);
    close = button(text()[1], header, hide);
    status = element('p', '', panel); status.setAttribute('role', 'status');
    list = element('div', '', panel);
    dialog.addEventListener('keydown', event => {
      if (event.key === 'Escape') { event.preventDefault(); hide(); }
      if (event.key === 'Tab') {
        const buttons = [...dialog.querySelectorAll('button:not(:disabled)')];
        if (!buttons.length) { event.preventDefault(); return; }
        const first = buttons[0], last = buttons[buttons.length - 1];
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
        else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
      }
    });
    api.setModal(true); render(); close.focus();
    const opening = dialog;
    api.refresh().finally(() => {
      if (dialog !== opening) return;
      loading = false;
      render();
    });
  };
  api.listen(render);
})();
