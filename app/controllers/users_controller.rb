# frozen_string_literal: true

class UsersController < ApplicationController
    layout false, only: [:signin, :signup]
    require 'bcrypt'

    def index 
        @u1=check_logged_in
        if Order.where(:user_id=>@u1['id']).order(created_at: :desc)
            @orders=Order.where(:user_id=>@u1['id']).order(created_at: :desc)
        end
        @friends=Friendship.where(:friend_a_id => @u1['id']).or(Friendship.where(:friend_b_id => @u1['id']))
        p @friends
        @friendOrders=[]
        @friends.each do |f|
            friend_id= f['friend_a_id'] == @u1['id']? f['friend_b_id']: f['friend_a_id']  
                @friendOrders.push(* Order.where(:user_id => friend_id).order(created_at: :desc))
        end
        p @friendOrders
        if @u1 == nil
            redirect_to :signin
        end
    end

    def signin_form
        user_email = params[:user_email]
        password = params[:user_password]
        encrypted_password = ""

        is_regestered_user = User.where(email: user_email).first

        # check the user's login password with the encrpted pass from the database.
        if BCrypt::Password.new(is_regestered_user.password) == password
            session[:logged_in_user] = is_regestered_user
            redirect_to ""
        else
            render 'users/signin'
        end
    end

    def check_logged_in
        if session[:logged_in_user] != nil
            logged_in_user = session[:logged_in_user]
            return logged_in_user
        else
            return nil
        end
    end

    def log_out
        reset_session
        redirect_to :signin
    end

    # signin method for the html rendering
    def signin
        unless check_logged_in == nil
            redirect_to ""
        end
    end

    # signup method for the html renderig
    def signup
        @user = User.new
        unless check_logged_in == nil
            redirect_to ""
        end
    end


    def friends
        @u1=check_logged_in
        p @u1
        if @u1 == nil
            return redirect_to :signin
        end
        @friends_list = User.find_by_id(@u1['id']).friends
        return @friends_list
    end

    def addnewFriend    
        newFriendEmail =params[:friend_email]+".com"
        @u1=check_logged_in
        if @u1 == nil
            redirect_to :signin
        end
        @friends_list = User.find_by_id(@u1['id']).friends
        found= false
        if newFriendEmail.length > 0
            @friends_list.each do |f|
                if f.email == newFriendEmail
                    found=true
                    break
                end
            end

            if found
                flash[:alert]= "Already Friends!!"
            else
                friend=User.find_by_email(newFriendEmail)
                Friendship.create(:friend_a_id=>@u1['id'],:friend_b_id=>friend.id)
            end
        else
            flash[:alert]= "Enter Valid Email!!"
        end
    end

    def deleteFriend
        @u1=check_logged_in
        p @u1
        if @u1 == nil
            redirect_to :signin
        end
        f = Friendship.where(friend_a_id: @u1['id'], friend_b_id: params[:friend_id]).first()
        if f
            Friendship.delete(f.id)
        else
            f = Friendship.where(friend_b_id: @u1['id'], friend_a_id: params[:friend_id]).first()
            Friendship.delete(f.id)
        end
        redirect_to :friends
    end


    def signup_form
        user_full_name = params['user_full_name'].to_s
        user_email = params['user_email_address'].to_s
        user_password = params['user_password'].to_s
        user_confirmation_password = params['user_confirmation_password'].to_s
    
        @user = User.new
        # checking the vlidation of the email and the password and if true create a new user.
        if check_password(user_password, user_confirmation_password)
            my_password = BCrypt::Password.create(user_password)#=>
            @user = User.create(name: user_full_name, email: user_email, password: my_password)
            if @user.errors.any?
                render 'users/signup'
            else
                session[:logged_in_user] = @user
                redirect_to :groups
            end 
        else
            render 'users/signup'
        end
    end
        
    def check_password(user_password, confirm_password)
        if (user_password != nil) && (confirm_password != nil)
            if (user_password == confirm_password)
                return true
            else 
                return false
            end
        else
            return false
        end
    end

  def groups
    @u1=check_logged_in
    p @u1
    if @u1 == nil
        return redirect_to :signin
    end
    @group = Group.new
    @groups = Group.eager_load(:users).where(:user_id =>@u1['id'])
  end

  def new_group
    @u1=check_logged_in
    p @u1
    if @u1 == nil
        redirect_to :signin
    end
    @group = Group.new(params.require(:group).permit(:name))
    @group.user_id = @u1['id']
    if @group.save
      redirect_to :groups
    else
      @groups = Group.eager_load(:users).where(:user_id =>@u1['id'])
      render :groups
    end

  end

  def delete_group
    Group.find(params[:id]).delete
    redirect_to :groups
  end

  def delete_group_user
    Group.find(params[:id]).users.delete(params[:user_id])
    redirect_to :groups
  end

  def add_group_user
    @u1=check_logged_in
    p @u1
    if @u1 == nil
        redirect_to :signin
    end
    user = User.find(@u1['id'])
    friend = user.friends.detect{|f| f.name.casecmp(params[:user_name]) == 0}
    p friend
    if friend
      Group.find(params[:id]).users << friend
    end
    redirect_to :groups
  end

    def is_friend
        @u1=check_logged_in
        p @u1
        if @u1 == nil
            redirect_to :signin
        end
        @friends_list = User.find_by_id(@u1['id']).friends
        @friend = nil

        newFriendEmail = params[:email]
        if newFriendEmail.match(/^.+@.+$/)
            if newFriendEmail.length > 0
                @friends_list.each do |f|
                    if f.email == newFriendEmail
                        p "found"
                        @friend = f
                        break
                    end
                end
            end
            if @friend
                msg = [{:id => @friend.id, :email => @friend.email, :name => @friend.name}]
                return render :json => msg
            end
        else
            p newFriendEmail
            @group= Group.where(:user => @u1['id'],:name => newFriendEmail).first
            msg=[]
            if @group
                @group.users.each do |friend|
                    msg.append({:id => friend.id, :email => friend.email, :name => friend.name})   
                end
                return render :json => msg   
            end     
        end

        return render :json => {:error => "not-found"}.to_json, :status => 404 
    end
end
