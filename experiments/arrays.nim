{.experimental: "views".}

var things = newSeq[openArray[char]]()
var buffer = newSeq[char]()

buffer.add 'a'
buffer.add 'b'
buffer.add 'c'
buffer.add 'd'
buffer.add 'e'

var view = buffer.toOpenArray(0, -1)
echo view
