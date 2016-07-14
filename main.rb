# 表示用
class Integer
	def comma; self.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,'); end
end

# 引数のパース
require 'optparse'
@params = ARGV.getopts('', 'tiles:0', 'output:result', 'message:', 'wall:0.1', 'epsilon:0.5', 'random')
puts @params
EPSILON = @params['epsilon'].to_f
GAMMA = 0.9
def alpha(t); 1.0/(t+1); end

# データ設定
@tiles = [[
	[0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 2, 0],
	[0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0]].transpose,
[
	[0, 0, 0, 0, 0, 0],
	[0, 3, 3, 3, 3, 0],
	[0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 2, 0],
	[0, 1, 0, 0, 3, 3],
	[0, 0, 0, 0, 0, 0]].transpose,
][@params['tiles'].to_i]
@actions = [[-1, 0],[1, 0],[0, -1],[0, 1]]
@arrows = ['←','→','↑','↓']
@passed = 6.times.map{ 6.times.map{ [0,0,0,0] }}
@times = {loop: 0, action: 0}
q = 6.times.map{ 6.times.map{ [0,0,0,0] }}

# 次の動作を決定する
def next_action(q, x, y)
	(rand < EPSILON) ? q[x][y].index(q[x][y].max) : [0,1,2,3].sample
end

# 移動して強化信号を得る
def move(x, y, a)
	return [x, y, 0] if @tiles[x][y] != 0
	x_ = x + @actions[a][0]
	y_ = y + @actions[a][1]
	return [x, y, -@params['wall'].to_f] if !x_.between?(0,5) || !y_.between?(0,5) || @tiles[x_][y_] == 3
	[x_, y_, @tiles[x_][y_]]
end

# 収束するまでループ
while true
	diff = 0.0
	1000.times do
		@times[:loop] += 1
		x, y, r = [0, 0, 0]
		x, y = 2.times.map{ (0..5).to_a.sample } if @params['random']
		next if @tiles[x][y] > 0

		while r <= 0
			@times[:action] += 1
			a = next_action(q, x, y)
			@passed[x][y][a] += 1
			alp = alpha(@passed[x][y][a])
			x_, y_, r = move(x, y, a)
			old_q = q[x][y][a]
			q[x][y][a] = (1-alp)*q[x][y][a] + alp*( r + GAMMA*q[x_][y_].max )
			diff += (old_q - q[x][y][a]).abs
			x=x_; y=y_
		end
	end
	puts "diff = #{diff}"
	break if diff < 10e-4
end
puts "loop: #{@times[:loop]}, action: #{@times[:action]}"


# ===========================================
# ここから下は、PDFへ出力するための関数である
# ===========================================

def line(x1, y1, x2, y2)
	@context.move_to(x1, y1)
	@context.line_to(x2, y2)
	@context.stroke
end
def lines(*points)
	@context.move_to(*points.last)
	points.each{|p| @context.line_to(*p) }
	@context.stroke
end
def rect(x1, y1, width, height)
	@context.rectangle(x1, y1, width, height)
	@context.stroke
end
def drawtext(x1, x2, text)
	@context.move_to(x1, x2)
	@context.show_text(text)
end

require 'cairo'
width=670; height=700
surface = Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, width, height)
@context = Cairo::Context.new(surface)

@context.font_size = 15
@context.set_source_rgb(1, 1, 1)
@context.rectangle(0, 0, width, height)
@context.fill
@context.set_source_rgb(0, 0, 0)
drawtext(10, 25, "#{@params['message']} 試行回数 : #{@times[:action].comma}回")

q.each_with_index do |_, x|
	_.each_with_index do |a, y|
		left, right, up, down = a.map{|o| o }
		cx = 110*x+60; cy = 110*y+90
		# 枠
		@context.set_line_width(1)
		rect(cx-50, cy-50, 100, 100)
		if @tiles[x][y] != 0
			drawtext(cx-45, cy-30, ['','G2','G1','Wall'][@tiles[x][y]])
			next
		end
		@context.set_line_width(0.3)
		line(cx-50, cy, cx+50, cy)
		line(cx, cy-50, cx, cy+50)
		# 1のライン
		lines([cx,cy-25], [cx+25,cy], [cx,cy+25], [cx-25,cy])
		# Qの値
		@context.set_line_width(1)
		lines(
			[cx-(left*25),cy],
			[cx, cy-(up*25)],
			[cx+(right*25), cy],
			[cx, cy+(down*25)]
		)
		# 通過率
		drawtext(cx-45, cy-30, "#{@arrows[a.index(a.max)]} #{@passed[x][y].inject(&:+)*100/@times[:loop]}%")
	end
end
surface.write_to_png("#{@params['output']}.png")
