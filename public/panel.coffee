window.getReadableBandwidth = (bytes, max) ->
  bytes = Number bytes
  sizes = ["Bytes", "KB", "MB", "GB", "TB"]
  posttxt = 0
  if max isnt undefined and bytes is 0
    return "infinite"
  while bytes >= 1024
    posttxt++
    bytes = bytes / 1024
  return bytes.toFixed(2).toString() + " " + sizes[posttxt]

window.displayBandwidth = (b, mb) ->
  document.getElementById("bandwidth").innerHTML = getReadableBandwidth b
  document.getElementById("maxBandwidth").innerHTML = getReadableBandwidth mb, true
  percent = (b*100)/mb
  document.getElementById("percent").style.width = percent+"%"
  document.getElementById("percentstring").innerHTML = "("+Math.round(percent*100)/100+"%)"
  if percent > 80
    document.getElementById("percentbar").setAttribute "class", "meter red"

window.showKey = () ->
  document.getElementById("apikeycontainer").children[0].innerHTML = document.getElementById("apikeycontainer").children[0].id + " "
  document.getElementById("apikeylink").onclick = hideKey
  document.getElementById("apikeylink").innerHTML = "hide key"
  
window.hideKey = () ->
  document.getElementById("apikeycontainer").children[0].innerHTML = ""
  document.getElementById("apikeylink").onclick = showKey
  document.getElementById("apikeylink").innerHTML = "show key"

window.sayHola = () ->
  holas = ["Hola", "Hello", "Aloha", "Konnichiwa", "Bonjour", "Guten tag", "Buon giorno", "Al salaam a’alaykum", "Ni hao", "Hallo"]
  hola = localStorage.getItem "hola"
  if hola is null || hola > 9
    hola = 0
  document.getElementById("hola").innerHTML = holas[hola]
  localStorage.setItem("hola", ++hola)

window.drawLastMonthChart = () ->

  date = new Date()
  today = new Date()
  dataArray = new Array()
  i = 0
  max = 0
  previoussum = 0
  while i <= 30
    date = new Date today.getTime() - (i * 24 * 60 * 60 * 1000)
    day = date.getDate()
    month = date.getMonth()
    j = 0
    sum = 0
    while j < queries.length
      queryDate = Date.parse queries[j].date
      queryDate = new Date queryDate
      queryDay = queryDate.getDate()
      queryMonth = queryDate.getMonth()
      if day is queryDay and month is queryMonth
        sum += queries[j].length
      j++
    if sum > previoussum
      max = sum
    previoussum = sum
    dataArray.push [date, parseFloat(getReadableBandwidth(sum).split(" ")[0])]
    i++

  unit = getReadableBandwidth(max).split(" ")[1]

  data = new google.visualization.DataTable()
  data.addColumn 'date', 'Date'
  data.addColumn 'number', 'Bandwidth'
  data.addRows dataArray

  options =
    width: 900
    height: 500
    vAxis: format:'#,###.# '+unit
    title: "Last month Bandwidth usage"
    pointSize: 5

  chart = new google.visualization.LineChart document.getElementById 'chart'
  chart.draw data, options

window.drawLastMonthChartByQueries = () ->

  date = new Date()
  today = new Date()
  dataArray = new Array()
  i = 0
  while i <= 30
    date = new Date today.getTime() - (i * 24 * 60 * 60 * 1000)
    day = date.getDate()
    month = date.getMonth()
    j = 0
    sum = 0
    number = 0
    while j < queries.length
      queryDate = Date.parse queries[j].date
      queryDate = new Date queryDate
      queryDay = queryDate.getDate()
      queryMonth = queryDate.getMonth()
      if day is queryDay and month is queryMonth
        ++number
      j++
    dataArray.push [date, number]
    i++

  data = new google.visualization.DataTable()
  data.addColumn 'date', 'Date'
  data.addColumn 'number', 'Queries'
  data.addRows dataArray

  options =
    width: 900
    height: 500
    vAxis: format:'#.#'
    colors: ["#C2131B"]
    title: "Last month Queries"
    pointSize: 5

  chart = new google.visualization.LineChart document.getElementById 'chart'
  chart.draw data, options

window.changeChart = (val) ->
  if val is '0'
    drawLastMonthChart()
  else if val is '1'
    drawLastMonthChartByQueries()

window.onload = () ->
  displayBandwidth bandwidth, maxBandwidth
  sayHola()
  google.load 'visualization', '1.0', {'packages':['corechart'], 'callback': drawLastMonthChart}

