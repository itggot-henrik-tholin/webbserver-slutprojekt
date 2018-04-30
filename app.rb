class App < Sinatra::Base
	enable :sessions
	register Sinatra::Flash
	
	db = SQLite3::Database.open('db/db.sqlite')
	colors = ["orange", "green", "cyan", "red", "blue"]

	helpers do
		def display(file)
			slim file
		end

		def time_ago_in_words(time)
			timeAgo = (DateTime.now.to_time - DateTime.parse(time).to_time)
			if timeAgo / (60*60*24) < 1
				if timeAgo / (60*60) < 1
					if timeAgo / 60 < 1
						return "#{timeAgo.to_i}s"
					else
						return "#{(timeAgo / 60).to_i}min"
					end
				else
					return "#{(timeAgo / (60*60)).to_i}h"
				end
			else
				return "#{(timeAgo / (60*60*24)).to_i}d"
			end
		end
	end
	
	before do
		if session[:username]
			@user = db.execute("SELECT * FROM accounts WHERE username = ?", session[:username]).first
		end

		unless @title
			@title = "Yodel"
		end
	end
	
	get '/not_found' do
		status 404
		@title = "Not found"
		slim :not_found
	end
	
	get '/denied' do
		status 403
		@title = "Denied"
		slim :denied
	end

	get '/' do
		unless @user
			redirect '/login'
		end

		user_channels = db.execute("SELECT channel FROM channel_membership WHERE account = ?", @user[0])
		if user_channels.empty?
			@posts = db.execute("SELECT * FROM posts ORDER BY id DESC")
		else
			sql = "SELECT * FROM posts WHERE channel = 0 OR "
			endsql = " ORDER BY id DESC"
			user_channels.each_with_index do |usr_chan, i|
				if i == (user_channels.length - 1)
					sql += "channel = #{usr_chan.first}"
				else
					sql += "channel = #{usr_chan.first} OR "
				end
			end

			query = sql + endsql
			@posts = db.execute(query)
		end

		@channel_posts = []
		for post in @posts
			if post[7] > 0
				channel = db.execute("SELECT * FROM channels WHERE id = ?", post[7]).first
				@channel_posts.push(channel)
			else
				@channel_posts.push(nil)
			end
			comments = db.execute("SELECT COUNT(id) FROM comments WHERE post = ?", post.first).first.first
			post.push(comments)
		end

		slim :index
	end

	get '/register' do
		if @user
			redirect '/'
		end

		@title = "Register account"

		slim :register
	end

	post '/register' do
		if @user
			redirect '/'
		end

		username = params['username']
		password = params['password']
		email = params['email']

		errors = []

		if username.empty?
			errors.push("Username cannot be empty.")
		end
		if password.empty?
			errors.push("Password cannot be empty.")
		end
		if email.empty?
			errors.push("Email cannot be empty.")
		end

		if errors.empty?
			username_check = db.execute("SELECT username FROM accounts WHERE username = ?", username)
			email_check = db.execute("SELECT email FROM accounts WHERE email = ?", email)

			if !username_check[0].nil?
				errors.push("Username is already in use.")
			end
			if !email_check[0].nil?
				errors.push("Email is already in use.")
			end

			unless errors.empty?
				flash[:error] = errors
				redirect back
			end
		else
			flash[:error] = errors
			redirect back
		end

		bcrypt_password = BCrypt::Password.create(password)
		db.execute("INSERT INTO accounts (username, password, email) VALUES (?, ?, ?)", username, bcrypt_password, email)
		session[:username] = username
		flash[:success] = "Welcome to Yodel!"
		redirect '/'
	end

	get '/login' do
		if @user
			redirect '/'
		end
		
		@title = "Login"
		slim :login
	end

	post '/login' do
		if @user
			redirect '/'
		end

		username = params['username']
		password = params['password']
		user_info = db.execute("SELECT username, password FROM accounts WHERE username = ?", username).first
		if user_info.nil?
			flash[:error] = "Username or password is invalid"
		else
			bcrypt_password = BCrypt::Password.new(user_info[1])
			if (user_info[0].downcase == username.downcase) && (bcrypt_password == password)
				session[:username] = username
				redirect '/'
			else
				flash[:error] = "Username or password is invalid"
			end
		end
		redirect back
	end

	get '/logout' do
		session.destroy
		redirect '/login'
	end

	get '/post/new' do
		unless @user
			redirect '/login'
		end

		slim :new_post
	end

	post '/post/new' do
		unless @user
			redirect '/login'
		end

		text = params['text']
		coords = params['coords']
		channel = params['chan']

		if text.empty?
			flash[:error] = "Yodel cannot be empty."
			redirect back
		elsif !channel.empty?
			db.execute("INSERT INTO posts (text, owner, coords, color, channel) VALUES (?, ?, ?, ?, ?)", text, @user[0], coords, colors.sample, channel)
			redirect "/channel/#{channel}"
		else
			db.execute("INSERT INTO posts (text, owner, coords, color) VALUES (?, ?, ?, ?)", text, @user[0], coords, colors.sample)
			redirect '/'
		end
	end

	get '/post/:id' do
		unless @user
			redirect '/login'
		end

		id = params['id']
		@post = db.execute("SELECT * FROM posts WHERE id = ?", id).first
		@comments = db.execute("SELECT * FROM comments WHERE post = ?", id)

		slim :post
	end

	post '/post/:id/vote/up' do
		unless @user
			redirect '/login'
		end

		id = params['id']

		voteCheck = db.execute("SELECT * FROM votes WHERE post = ? AND account = ?", id, @user[0]).first
		unless voteCheck.nil? || voteCheck.empty?
			flash[:error] = "You have already voted"
			redirect back
		end

		post_owner = db.execute("SELECT owner FROM posts WHERE id = ?", id).first.first
		unless post_owner == @user[0]
			db.execute("INSERT INTO votes (post, account, vote) VALUES (?, ?, ?)", id, @user[0], 1)
			db.execute("UPDATE posts SET votes = votes + 1 WHERE id = ?", id)
			# adds 10 karma to post owner
			db.execute("UPDATE accounts SET karma = karma + 10 WHERE id = ?", post_owner)
			# 2 karma for each upvote
			db.execute("UPDATE accounts SET karma = karma + 2 WHERE id = ?", @user[0])
		end
	end

	post '/post/:id/vote/down' do
		unless @user
			redirect '/login'
		end

		id = params['id']

		voteCheck = db.execute("SELECT * FROM votes WHERE post = ? AND account = ?", id, @user[0])
		unless voteCheck.nil? || voteCheck.empty?
			flash[:error] = "You have already voted"
			redirect back
		end

		post_owner = db.execute("SELECT owner FROM posts WHERE id = ?", id).first.first
		unless post_owner == @user[0]
			db.execute("INSERT INTO votes (post, account, vote) VALUES (?, ?, ?)", id, @user[0], -1)
			db.execute("UPDATE posts SET votes = votes - 1 WHERE id = ?", id)
			# removes 10 karma from post owner
			db.execute("UPDATE accounts SET karma = karma - 10 WHERE id = ?", post_owner)
			# -2 karma for each downvote
			db.execute("UPDATE accounts SET karma = karma - 2 WHERE id = ?", @user[0])
		end
	end

	post '/post/:id/comment' do
		unless @user
			redirect '/login'
		end

		id = params['id']
		text = params['comment']

		comments = db.execute("SELECT * FROM comments WHERE post = ?", id)
		post_owner = db.execute("SELECT owner FROM posts WHERE id = ?", id).first.first
		identCheck = db.execute("SELECT identifier FROM comments WHERE post = ? AND owner = ?", id, @user[0]).first
		
		if post_owner == @user[0]
			identifier = 0
		elsif comments.empty?
			identifier = 1
		elsif identCheck.nil?
			identifier = db.execute("SELECT identifier FROM comments WHERE post = ? ORDER BY identifier DESC", id).first.first
			identifier += 1
		else
			identifier = identCheck
		end

		db.execute("INSERT INTO comments (text, post, owner, identifier) VALUES (?, ?, ?, ?)", text, id, @user[0], identifier)
		
		redirect back
	end

	post '/post/:post/comment/:comment/vote/up' do
		unless @user
			redirect '/login'
		end

		post_id = params['post']
		comment_id = params['comment']

		voteCheck = db.execute("SELECT * FROM votes WHERE post = ? AND comment = ? AND account = ?", post_id, comment_id, @user[0]).first
		unless voteCheck.nil?
			flash[:error] = "You have already voted"
			redirect back
		end

		comment_owner = db.execute("SELECT owner FROM comments WHERE id = ?", comment_id).first.first
		unless comment_owner == @user[0]
			db.execute("INSERT INTO votes (post, account, vote, comment) VALUES (?, ?, ?, ?)", post_id, @user[0], 1, comment_id)
			db.execute("UPDATE comments SET votes = votes + 1 WHERE id = ?", comment_id)
			# adds 10 karma to post owner
			db.execute("UPDATE accounts SET karma = karma + 10 WHERE username = ?", comment_owner)
			# 2 karma for each upvote
			db.execute("UPDATE accounts SET karma = karma + 2 WHERE username = ?", @user[1])
		end
	end

	post '/post/:post/comment/:comment/vote/down' do
		unless @user
			redirect '/login'
		end

		post_id = params['post']
		comment_id = params['comment']

		voteCheck = db.execute("SELECT * FROM votes WHERE post = ? AND comment = ? AND account = ?", post_id, comment_id, @user[0]).first
		unless voteCheck.nil?
			flash[:error] = "You have already voted"
			redirect back
		end

		comment_owner = db.execute("SELECT owner FROM comments WHERE id = ?", comment_id).first.first
		unless comment_owner == @user[0]
			db.execute("INSERT INTO votes (post, account, vote, comment) VALUES (?, ?, ?, ?)", post_id, @user[0], -1, comment_id)
			db.execute("UPDATE comments SET votes = votes - 1 WHERE id = ?", comment_id)
			# removes 10 karma from post owner
			db.execute("UPDATE accounts SET karma = karma - 10 WHERE username = ?", comment_owner)
			# -2 karma for each upvote
			db.execute("UPDATE accounts SET karma = karma - 2 WHERE username = ?", @user[1])
		end
	end

	get '/channels' do
		unless @user
			redirect '/login'
		end

		@channels = db.execute("SELECT * FROM channels")
		for channel in @channels
			member_count = db.execute("SELECT COUNT(id) FROM channel_membership WHERE channel = ?", channel[0]).first.first
			channel.push(member_count)
		end

		channel_membership = db.execute("SELECT * FROM channel_membership WHERE account = ?", @user[0])
		@user_channels = []
		for channel in channel_membership
			member = db.execute("SELECT * FROM channels WHERE id = ?", channel[1]).first
			member_count = db.execute("SELECT COUNT(id) FROM channel_membership WHERE channel = ?", channel[1]).first.first
			member.push(member_count)
			@user_channels.push(member)

			@channels.each_with_index do |c, i|
				if c[0] == channel[1]
					@channels.delete_at(i)
				end
			end
		end

		slim :channels
	end

	post '/channel/new' do
		unless @user
			redirect '/login'
		end

		name = params['name']
		unless name.nil?
			db.execute("INSERT INTO channels (name) VALUES (?)", name)
		end
		redirect '/channels'
	end

	get '/channel/:id' do
		unless @user
			redirect '/login'
		end

		id = params['id'].to_i
		if id <= 0
			redirect '/'
		end

		@channel = db.execute("SELECT * FROM channels WHERE id = ?", id).first
		memberCheck = db.execute("SELECT id FROM channel_membership WHERE channel = ? AND account = ?", id, @user[0]).first
		@member = memberCheck.nil? ? false : true

		@posts = db.execute("SELECT * FROM posts WHERE channel = ? ORDER BY id DESC", id)
		for post in @posts
			comments = db.execute("SELECT COUNT(id) FROM comments WHERE post = ?", post.first).first.first
			post.push(comments)
		end

		slim :channel
	end

	get '/channel/:id/join' do
		unless @user
			redirect '/login'
		end

		id = params['id']
		channelCheck = db.execute("SELECT id FROM channels WHERE id = ?", id).first
		unless channelCheck.nil?
			db.execute("INSERT INTO channel_membership (channel, account) VALUES (?, ?)", id, @user[0])
		end

		redirect back
	end

	get '/channel/:id/leave' do
		unless @user
			redirect '/login'
		end

		id = params['id']
		channelCheck = db.execute("SELECT id FROM channels WHERE id = ?", id).first
		unless channelCheck.nil?
			db.execute("DELETE FROM channel_membership WHERE channel = ? AND account = ?", id, @user[0])
		end

		redirect back
	end
end