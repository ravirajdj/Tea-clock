SOUND = true
CANCEL_TIMEOUT = 10000
CHOSEN_TEA = "chosen_tea"
CUSTOM_TIMER = "custom_timer"
CHOSEN_DEGREE = "chosen_degree"

angular.module('tea', ['vr.directives.slider'])

#Filters
angular.module('tea').filter('time', () ->
    (input) ->
        Utils.formatTime(input)
)
angular.module('tea').filter('i18n', ['localize', (localize) ->
    (input) ->
        if input != undefined
            localize.getLocalizedString(input)
])

#Services
angular.module('tea').service('teaSelection', ['$rootScope', ($rootScope) ->
    selection = {
        tea: window.teas[0].name,
        degree: window.degrees[0].name
    }

    this.storeSelection = (newSelection) ->
        selection = newSelection
        localStorage.setItem(CHOSEN_TEA, selection.tea)
        localStorage.setItem(CUSTOM_TIMER, selection.timer)
        localStorage.setItem(CHOSEN_DEGREE, selection.degree)

    this.getSelection = () ->
        return selection

    this.broadcastSelection = (selection) ->
        $rootScope.$broadcast('$teaSelected', selection)

    this.init = () ->
        item = localStorage.getItem(CHOSEN_TEA)
        if localStorage.getItem(CHOSEN_TEA)
            #This might not be initialized
            degs = 'celsius'
            if localStorage.getItem(CHOSEN_DEGREE)
                degs = localStorage.getItem(CHOSEN_DEGREE)
            selection = {
                tea: localStorage.getItem(CHOSEN_TEA)
                degree: degs
                timer: localStorage.getItem(CUSTOM_TIMER)
            }

    return this
])
angular.module('tea').service('localize', ($rootScope, $locale, $http, $filter) ->
    self = this
    this.dictionary = []
    this.resourceFileLoaded = false
    this.dictionary = ''

    this.successCallback = (data) ->
        self.dictionary = data
        this.resourceFileLoaded = true
        $rootScope.$broadcast('localizeResourcesUpdates')

    this.initLocalizedResources = () ->
        url = 'i18n/resources-locale.js'

        $http({ method: "GET", url: url, cache: false })
        .success(this.successCallback).error(() ->
            url = 'i18n/resources-locale.js.en'
            $http({ method: "GET", url: url, cache: false })
            .success(this.successCallback)
        )

    this.getLocalizedString = (value) ->
        result = ''

        if this.dictionary != [] && this.dictionary.length > 0
            entry = $filter('filter')(this.dictionary, (element) ->
                return element.key == value
            )[0]
            result = entry.value

        return result

    return this
)

angular.module('tea').run((teaSelection, localize) ->
    localize.initLocalizedResources()
    teaSelection.init()
)

angular.module('tea').controller("ControlPanelController", ($scope, $timeout, teaSelection, localize, Notification) ->
    self = this

    $scope.radio = {index: 0}
    $scope.teas = window.teas
    $scope.degrees = window.degrees

    $scope.$on('$teaSelected', (evt, selection) ->
        self.setFromSelection(selection)
    )

    this.setFromSelection = (selection) ->
        if selection.tea
            for tea in $scope.teas
                if tea.name == selection.tea
                    $scope.tea = tea
                    $scope.tea.checked = true

        if selection.degree
            for degree in $scope.degrees
                if degree.name == selection.degree
                    $scope.chosenDegree = degree

        $scope.time = selection.timer || $scope.tea.time

    this.setFromSelection(teaSelection.getSelection())

    $scope.setTea = (tea) ->
        currentSelection = teaSelection.getSelection()
        currentSelection.tea = tea.name
        currentSelection.timer = tea.time
        teaSelection.broadcastSelection(currentSelection)

    $scope.setDegree = (degree) ->
        currentSelection = teaSelection.getSelection()
        currentSelection.degree = degree.name
        currentSelection.timer = $scope.time
        teaSelection.broadcastSelection(currentSelection)

    $scope.start = () ->
        Notification.checkPermission()
        $scope.onTimerStart()

    $scope.onTimerStart = () ->
        console.log("Starting timer for: " + $scope.time)

        teaSelection.storeSelection({
            tea: $scope.tea.name
            degree: $scope.chosenDegree.name
            timer: $scope.time
        })

        $scope.displayName = $scope.tea.title
        $scope.actualTime = $scope.time
        $scope.timer = true

        $('#countdownModal').modal()
        $('#countdownModal').on('hidden', ->
            $scope.timer = false)

        #Google Analytics
        Utils.gaTrack(localStorage[CHOSEN_TEA], $scope.chosenDegree.name, $scope.time)

        $timeout($scope.onTick, 1000)

    $scope.onTick = () ->
        $scope.actualTime -= 1
        if ($scope.timer && $scope.actualTime >= 0)
            updateTitle($scope.actualTime)
            $timeout($scope.onTick, 1000)
        else
            $('#countdownModal').modal("hide")
            resetTitle()
            #Display notification only if timer enabled!
            if $scope.timer
                Notification.display(localize.getLocalizedString('_AppTitle_'),
                    localize.getLocalizedString('_NotificationMessage_'))

    updateTitle = (time) ->
        document.title = "[#{Utils.formatTime(time)}] " + localize.getLocalizedString('_AppTitle_')

    resetTitle = () ->
        document.title = localize.getLocalizedString('_AppTitle_')

    $scope.$watch('time', (time) ->
        currentSelection = teaSelection.getSelection()
        currentSelection.timer = time
        teaSelection.broadcastSelection(currentSelection)
    )
)

angular.module('tea').controller("InfoPanelController", ($scope, teaSelection) ->
    self = this

    $scope.$on('$teaSelected', (evt, selection) ->
        self.setFromSelection(selection)
    )

    this.setFromSelection = (selection) ->
        if selection.tea
            for item in window.teas
                if item.name == selection.tea
                    tea = item

        if selection.degree
            for degree in window.degrees
                if degree.name == selection.degree
                    $scope.chosenDegree = degree

        $scope.displayName = tea.title
        $scope.time = selection.timer || tea.time
        $scope.displayTime = $scope.time
        $scope.displayTemp = Utils.convertTemp($scope.chosenDegree, tea.temp)


    this.setFromSelection(teaSelection.getSelection())
)

angular.module('tea').service('Notification', ($timeout) ->
    snd = new Audio('snd/alarm.mp3')
    popup = null
    service = {}

    service.supported = () ->
        Notification

    service.checkPermission = () ->
        Notification.requestPermission() unless Notification.permission is "granted"

    service.display = (title, message) ->
        popup = new Notification(title, {
            body: message
            icon: "img/icon.png"
        })
        snd.play() if SOUND

        popup.onclick = () ->
            popup.close()

        popup.onclose = () ->
            snd.pause()

        $timeout(() ->
            #hide notification and stop sound
            cancel()
        , CANCEL_TIMEOUT)

    cancel = () ->
        popup.close() if popup
        snd.pause()


    return service
)

angular.module('tea').controller("RootController", ($scope, Notification) ->
    $scope.notificationSupported = Notification.supported
)

#Utils
class Utils

    Utils.formatTime = (secs) ->
        minutes = Math.floor(secs / 60)
        secs_remainder = secs - (minutes * 60)
        if (secs_remainder) < 10
            secs_remainder = "0" + secs_remainder
        return minutes + ":" + secs_remainder

    Utils.convertTemp = (degree, temperature) ->
        degreeType = degree.symbol
        tempIntervPos = temperature.search('-')
        convert = (tempString, degree) ->
            val = parseInt(tempString)
            degree.formula(val)

        if degreeType != 'C'
            if tempIntervPos > 0
                temp1 = temperature.substring(0, tempIntervPos)
                temp2 = temperature.substring(tempIntervPos + 1)
                convertedTemp = convert(temp1, degree) + ' - ' + convert(temp2, degree)
            else convertedTemp = convert(temperature, degree)
        else convertedTemp = temperature

        return convertedTemp.toString()

    Utils.gaTrack = (tea, degree, time) ->
        _gaq.push(['_trackEvent', 'start-tea', tea])
        _gaq.push(['_trackEvent', 'degree', degree])
        _gaq.push(['_trackEvent', 'start-time', time])
