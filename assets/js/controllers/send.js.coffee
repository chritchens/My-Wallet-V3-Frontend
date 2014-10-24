@SendCtrl = ($scope, $log, Wallet, $modalInstance, ngAudio, $timeout, $stateParams, $translate) ->
  
  $scope.advanced = false
  $scope.privacyGuard = false
  
  $scope.errors = {to: null, amount: null}
  
  $scope.alerts = Wallet.alerts
  
  $scope.currencies = {isOpen: false}
  
  $scope.setMethod = (method) ->
    $scope.method = method
    if method == "BTC"
      $scope.toPlaceholder = "1C9KKvTW94C4wiwqL5whVPUEAwmGJLXEvt"
    else if method == "EMAIL"
      $scope.toPlaceholder = "nic@blockchain.info"
    else
      $scope.toPlaceholder = "+18005550199"
    
    $scope.errors.to = null
    $scope.transaction.to = ""
    return
      
  $scope.max = (account) ->
    idx = $scope.accounts.indexOf(account)
    balance = account.balance.clone()
    fees = Wallet.recommendedTransactionFeeForAccount(idx, account.balance)
    max_btc = balance.subtract(fees).divide("100000000")
    return max_btc.format("0.[00000000]") + " BTC"
      
  
  
  
  $scope.transaction = {from: null, to: "", amount: "", currency: "BTC", privacyGuard: false, advanced: false}
  
  
  $scope.setMethod("BTC")
  
  
  $scope.addressBook = Wallet.addressBook
  $scope.accounts = Wallet.accounts
  

  $translate("ADVANCED").then (translation) ->
    $scope.advancedLabel = translation
  
  # QR Code scan. Uses js from this fork:
  # https://github.com/peekabustudios/webcam-directive/blob/master/app/scripts/webcam.js
  $scope.onError = (error) -> 
    # This never gets called...
    $translate("CAMERA_PERMISSION_DENIED").then (translation) ->
      Wallet.displayWarning(translation)
    
  $scope.processURLfromQR = (url) ->
    paymentRequest = Wallet.parsePaymentRequest(url)
    if paymentRequest.isValid
      $scope.transaction.to = paymentRequest.address
      $scope.transaction.amount = paymentRequest.amount if paymentRequest.amount
      $scope.transaction.currency = paymentRequest.currency if paymentRequest.currency

      $scope.cameraOff()
    else
      $translate("QR_CODE_NOT_BITCOIN").then (translation) ->
        Wallet.displayWarning(translation)

      $log.error "Not a bitcoin QR code:" + url
      
      $timeout((->
        $scope.lookForQR()
      ), 2000)
   
  qrcode.callback = $scope.processURLfromQR
  
  $scope.cameraOn = () ->
    $scope.cameraRequested = true
    
  $scope.cameraOff = () ->
    $scope.qrStream.stop()
    $scope.cameraIsOn = false
    $scope.cameraRequested = false
    
  $scope.onStream = (stream) -> # I removed the second argument in webcam.js!
    # Evil (TODO: use a directive to manipulate the DOM):
    canvas = document.getElementById("qr-canvas")
    $scope.qrStream = stream
        
    $scope.lookForQR()
    $scope.cameraIsOn = true
    
  $scope.lookForQR = () ->    
    try 
      canvas = document.getElementById("qr-canvas")
      video = document.getElementsByTagName("video")[0]
      
      if video.videoWidth > 0
        # This won't be set at the first iteration.
        canvas.width =  video.videoWidth
        canvas.height = video.videoHeight
           
        canvas.getContext("2d").drawImage(video,0,0)
      
      qrcode.decode()
    catch e
      # $log.error e
      $timeout((->
        $scope.lookForQR()
      ), 250)
      
  
  $scope.close = () ->
    Wallet.clearAlerts()
    $modalInstance.dismiss ""
  
  $scope.send = () ->
    Wallet.clearAlerts()

    if $scope.method == "EMAIL" || $scope.method == "SMS"
      Wallet.displayError("SMS and email not yet supported")
      return

    Wallet.send($scope.accounts.indexOf($scope.transaction.from), $scope.transaction.to, numeral($scope.transaction.amount), $scope.transaction.currency, $scope.observer)
  
  $scope.closeAlert = (alert) ->
    Wallet.closeAlert(alert)
    
  #################################
  #           Private             #
  #################################
  
  $scope.$watchCollection "accounts", () ->
    if $scope.transaction.from == null && $scope.accounts.length > 0
      if $stateParams.accountIndex == undefined || $stateParams.accountIndex == null || $stateParams.accountIndex == ""
        $scope.transaction.from = $scope.accounts[0]
      else 
        $scope.transaction.from = $scope.accounts[parseInt($stateParams.accountIndex)]
  
  $scope.$watchCollection "[transaction.to, transaction.from.address, transaction.amount]", () ->
    $scope.transaction.fee = Wallet.recommendedTransactionFeeForAccount($scope.accounts.indexOf($scope.transaction.from), numeral($scope.transaction.amount).multiply(100000000)).divide(100000000)
    $scope.transactionIsValid = $scope.validate()
    
  $scope.$watch "transaction.from", () ->
    $scope.visualValidate("from")
    
  $scope.visualValidate = (blurredField) ->
    if blurredField == "to"
      $scope.errors.to = null
    
    if blurredField == "amount"
      $scope.errors.amount = null
  
    transaction = $scope.transaction
    unless transaction.to? && transaction.to != ""
      if transaction.amount > 0 && blurredField == "to"
        if $scope.method == "BTC"
          $scope.errors.to = "Bitcoin address missing"
        else if $scope.method == "EMAIL"
          $scope.errors.to = "Email address missing"
        else if $scope.method == "SMS"
          $scope.errors.to = "Mobile phone number missing"
    
    if $scope.method == "BTC"
      unless Wallet.isValidAddress(transaction.to)
        if blurredField == "to"
          $scope.errors.to = "Invalid bitcoin address"
    else if $scope.method == "EMAIL"
      unless true
        if blurredField == "to"
          $scope.errors.to = "Invalid email address"   
    else if $scope.method == "SMS"
      unless true
        if blurredField == "to"
          $scope.errors.to = "Invalid international phone number."   
              
    
    unless transaction.amount? && transaction.amount > 0
      if blurredField == "amount" 
        $scope.errors.amount = "Please enter amount"

    if parseFloat(transaction.amount) + transaction.fee.value() > transaction.from.balance / 100000000
      console.log blurredField
      if blurredField == "amount" || blurredField == "from"
        $scope.errors.amount = "Insufficient funds"
  
    return 
    
  $scope.validate = () ->
    
    transaction = $scope.transaction
    unless transaction.to? && transaction.to != ""
      return false
      
    if $scope.method == "BTC"
      unless Wallet.isValidAddress(transaction.to)
        return false
    # else if $scope.method == "EMAIL"
    #
    # else if $scope.method == "SMS"
    
    $scope.errors.to = null
    
      
    unless transaction.amount? && transaction.amount > 0
      return false

    return false if parseFloat(transaction.amount) + $scope.transaction.fee.value()  > $scope.transaction.from.balance / 100000000
    return false if parseFloat(transaction.amount) == 0
    
    
    return false if transaction.currency != 'BTC'
    
    $scope.errors.amount = null
    
    
    return true
  
  $scope.observer = {}
  $scope.observer.transactionDidFailWithError = (message) ->
    Wallet.displayError(message)
  $scope.observer.transactionDidFinish = () ->
    sound = ngAudio.load("beep.wav")
    sound.play()
    $modalInstance.close ""
  
