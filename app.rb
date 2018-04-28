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

		@title = "Yodel"
		@karma = @user[4]

		@posts = db.execute("SELECT * FROM posts ORDER BY id DESC")

		# comments = []
		for post in @posts
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
			if (user_info[0].downcase == username.downcase) && (user_info[1] == bcrypt_password)
				session[:username] = username
				redirect '/'
			else
				flash[:error] = "Username or password is invalid"
			end
		end
		redirect back
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

		if text.empty?
			flash[:error] = "Yodel cannot be empty."
			redirect back
		else
			db.execute("INSERT INTO posts (text, owner, coords, color) VALUES (?, ?, ?, ?)", text, @user[1], coords, colors.sample)
			redirect '/'
		end
	end

	post '/post/:id/vote/up' do
		unless @user
			redirect '/login'
		end

		id = params['id']

		voteCheck = db.execute("SELECT * FROM votes WHERE post = ? AND account = ?", id, @user[0]).first
		unless voteCheck.nil?
			flash[:error] = "You have already voted"
			redirect back
		end

		post_owner = db.execute("SELECT owner FROM posts WHERE id = ?", id).first.first
		unless post_owner == @user[1]
			db.execute("INSERT INTO votes (post, account, vote) VALUES (?, ?, ?)", id, @user[0], 1)
			db.execute("UPDATE posts SET votes = votes + 1 WHERE id = ?", id)
			# adds 10 karma to post owner
			db.execute("UPDATE accounts SET karma = karma + 10 WHERE username = ?", post_owner)
			# 2 karma for each upvote
			db.execute("UPDATE accounts SET karma = karma + 2 WHERE username = ?", @user[1])
		end
	end

	post '/post/:id/vote/down' do
		unless @user
			redirect '/login'
		end

		id = params['id']

		voteCheck = db.execute("SELECT * FROM votes WHERE post = ? AND account = ?", id, @user[0])
		unless voteCheck.nil?
			flash[:error] = "You have already voted"
			redirect back
		end

		post_owner = db.execute("SELECT owner FROM posts WHERE id = ?", id).first.first
		unless post_owner == @user[1]
			db.execute("INSERT INTO votes (post, account, vote) VALUES (?, ?, ?)", id, @user[0], -1) unless 
			db.execute("UPDATE posts SET votes = votes - 1 WHERE id = ?", id)
			# removes 10 karma to post owner
			db.execute("UPDATE accounts SET karma = karma - 10 WHERE username = ?", post_owner)
			# -2 karma for each downvote
			db.execute("UPDATE accounts SET karma = karma - 2 WHERE username = ?", @user[1])
		end
	end
end