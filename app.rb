class App < Sinatra::Base
	enable :sessions
	register Sinatra::Flash
	
	db = SQLite3::Database.open('db/db.sqlite')

	helpers do
		def display(file)
			slim file
		end

		def time_ago_in_words(time)
			# format = "%T"
			# parsedTime = DateTime.strptime(time, format)
			timeAgo = (DateTime.now.to_time - DateTime.parse(time).to_time)
			p timeAgo
			# p timeAgo
			if timeAgo / 86400 < 1
				if timeAgo / 3600 < 1
					if timeAgo / 60 < 1
						return "#{timeAgo.to_i}s"
					else
						return "#{(timeAgo / 60).to_i}min"
					end
				else
					return "#{(timeAgo / 3600).to_i}h"
				end
			else
				return "#{(timeAgo / 86400).to_i}d"
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
		# @city = "Göteborg"
		@karma = @user[4]

		@colors = ["orange", "green", "cyan", "red", "yellow", "blue"]
		@posts = db.execute("SELECT * FROM posts ORDER BY id DESC")

		# for post in @posts
		# 	comments = db.execute("SELECT COUNT(id) FROM comments WHERE post = ?", post.first).first
		# 	@posts.push(comments)
		# end

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
end