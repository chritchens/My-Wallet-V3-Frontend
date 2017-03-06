angular
  .module('walletApp')
  .controller('BuySellCtrl', BuySellCtrl);

function BuySellCtrl ($rootScope, $scope, $state, Alerts, Wallet, currency, buySell, MyWallet, $cookies, $q, options) {
  $scope.buySellStatus = buySell.getStatus;
  $scope.trades = buySell.trades;

  $scope.status = {
    loading: false,
    modalOpen: false
  };

  $scope.walletStatus = Wallet.status;
  $scope.status.metaDataDown = $scope.walletStatus.isLoggedIn && !$scope.buySellStatus().metaDataService;

  $scope.tradeLimit = 5;
  $scope.scrollTrades = () => { $scope.tradeLimit += 5; };

  $scope.onCloseModal = () => {
    $scope.status.modalOpen = false;
    $scope.kyc = buySell.kycs[0];
    buySell.pollKYC();
  };

  $scope.initialize = () => {
    $scope.currencies = currency.coinifyCurrencies;
    $scope.settings = Wallet.settings;
    $scope.transaction = { fiat: undefined, currency: buySell.getCurrency() };
    $scope.currencySymbol = currency.conversions[$scope.transaction.currency.code];
    $scope.limits = {card: {}, bank: {}};
    $scope.state = {buy: true};
    $scope.rating = 0;

    $scope.buy = (trade, options) => {
      if (!$scope.status.modalOpen) {
        $scope.status.modalOpen = true;
        buySell.openBuyView(trade, options).finally($scope.onCloseModal);
      }
    };

    // for quote
    buySell.getExchange();

    $scope.$watch('settings.currency', () => {
      $scope.transaction.currency = buySell.getCurrency();
    }, true);

    $scope.$watch('transaction.currency', (newVal, oldVal) => {
      let curr = $scope.transaction.currency || null;
      $scope.currencySymbol = currency.conversions[curr.code];
      if (newVal !== oldVal) $scope.getMaxMin();
    });

    if (buySell.getStatus().metaDataService && buySell.getExchange().user) {
      $scope.status.loading = true;
      $scope.exchange = buySell.getExchange();

      buySell.fetchProfile().then(() => $q.all([
        buySell.getTrades().catch((error) => $q.reject({ error, type: 'trades' })),
        buySell.getKYCs().catch((error) => $q.reject({ error, type: 'kyc' })),
        buySell.getExchange().getBuyCurrencies().then(currency.updateCoinifyCurrencies)
      ])).then(() => {
        $scope.status.loading = false;
        $scope.status.disabled = false;
      }).catch((error) => {
        $scope.status.exchangeDown = true;
        if (error && error.type) {
          $scope.fetchTradeError = error.type === 'trades';
          $scope.fetchKYCError = error.type === 'kyc';
        }
      }).finally(() => {
        $scope.getMaxMin();

        let pending = buySell.trades.pending;
        $scope.pendingTrade = pending.sort((a, b) => b.id - a.id)[0];

        $scope.kyc = buySell.kycs[0];
        if ($scope.exchange) {
          if (+$scope.exchange.profile.level.name < 2) {
            if ($scope.kyc) {
              buySell.pollKYC();
            } else {
              buySell.getKYCs().then(kycs => {
                if (kycs.length > 0) buySell.pollKYC();
                $scope.kyc = kycs[0];
              });
            }
          }
        } else {
          $scope.$watch(buySell.getExchange, (ex) => $scope.exchange = ex);
        }
      });
    } else {
      $scope.status.disabled = false;
    }

    $scope.openKyc = () => {
      ['declined', 'rejected', 'expired'].indexOf($scope.kyc.state) > -1
        ? buySell.triggerKYC().then(kyc => $scope.buy(kyc))
        : $scope.buy($scope.kyc);
    };

    $scope.changeCurrency = (curr) => {
      if (curr && $scope.currencies.some(c => c.code === curr.code)) {
        $scope.transaction.currency = curr;
      }
    };

    $scope.submitFeedback = (rating) => buySell.submitFeedback(rating);
  };

  let watchLogin;

  if (Wallet.status.isLoggedIn) {
    $scope.initialize();
  } else {
    watchLogin = $scope.$watch('status.isLoggedIn', (isLoggedIn) => {
      if (isLoggedIn) {
        $scope.initialize();
        watchLogin();
      }
    });
  }

  $scope.getMaxMin = () => {
    const calculateMin = (rate) => {
      $scope.limits.card.min = (rate * 10).toFixed(2);
    };

    const calculateMax = (rate) => {
      $scope.limits.bank.max = buySell.calculateMax(rate, 'bank').max;
      $scope.limits.card.max = buySell.calculateMax(rate, 'card').max;
      $scope.limits.currency = $scope.currencySymbol;
    };

    buySell.getRate('EUR', $scope.transaction.currency.code).then(calculateMin);
    buySell.getRate($scope.exchange.profile.defaultCurrency, $scope.transaction.currency.code).then(calculateMax);
  };

  $scope.getIsTradingDisabled = () => {
    let profile = $scope.exchange && $scope.exchange.profile;
    let disabled = options.partners.coinify.disabled;
    let canTrade = profile && profile.canTrade;

    return canTrade === false || disabled;
  };

  $scope.getIsTradingDisabledReason = () => {
    let disabled = options.partners.coinify.disabled;
    let profile = $scope.exchange && $scope.exchange.profile;
    let cannotTradeReason = profile && profile.cannotTradeReason;

    if (disabled) cannotTradeReason = 'disabled';

    return cannotTradeReason;
  };

  $rootScope.$on('fetchExchangeProfile', () => {
    $scope.status.disabled = true;
    $scope.initialize();
  });
}
