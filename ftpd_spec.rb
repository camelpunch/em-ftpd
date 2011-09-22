# coding: utf-8

require 'rubygems'
require 'bundler/setup'
require 'ftpd'
require 'fake_ftp_server'

describe FTPServer do
  subject { FTPServer.new(nil) }

  describe "initialisation" do
    it "defaults to a root name_prefix" do
      subject.name_prefix.should eql("/")
    end

    it "responds with 220 when connection is opened" do
      subject.sent_data.should match(/220.+/)
    end
  end

  describe "ALLO" do
    it "always responds with 202 when called" do
      subject.reset_sent!
      subject.receive_line("ALLO")
      subject.sent_data.should match(/200.*/)
    end
  end

  describe "CDUP" do
    it "responds with 530 if user is not logged in" do
      subject.reset_sent!
      subject.receive_line("CDUP")
      subject.sent_data.should match(/530.*/)
      subject.name_prefix.should eql("/")
    end

    it "responds with 250 if called from root" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("CDUP")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/")
    end

    it "responds with 250 if called from incoming dir" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.reset_sent!
      subject.receive_line("CDUP")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/")
    end

  end

  describe "CWD" do
    it "responds with 530 if user is not logged in" do
      subject.reset_sent!
      subject.receive_line("CWD")
      subject.sent_data.should match(/530.*/)
    end

    it "responds with 250 if called with '..' from users home" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("CWD ..")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/")
    end

    it "responds with 250 if called with '.' from users home" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("CWD .")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/")
    end

    it "responds with 250 if called with '/' from users home" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("CWD /")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/")
    end

    it "responds with 250 if called with 'files' from users home" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("CWD files")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/files")
    end

    it "responds with 250 if called with 'files/' from users home" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("CWD files/")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/files")
    end

    it "responds with 250 if called with '/files/' from users home" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("CWD /files/")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/files")
    end

    it "responds with 250 if called with '..' from the files dir" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.reset_sent!
      subject.receive_line("CWD ..")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/")
    end

    it "responds with 250 if called with '/files' from the files dir" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.reset_sent!
      subject.receive_line("CWD /files")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/files")
    end

    it "responds with 550 if called with unrecognised dir" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.name_prefix.should eql("/")
      subject.receive_line("CWD test")
      subject.sent_data.should match(/550.+/)
      subject.name_prefix.should eql("/")
    end
  end

  describe "DELE" do
    it "always responds with 550 (permission denied) when called" do
      subject.reset_sent!
      subject.receive_line("DELE")
      subject.sent_data.should match(/550.+/)
    end
  end

  describe "HELP" do
    it "always responds with 214 when called" do
      subject.reset_sent!
      subject.receive_line("HELP")
      subject.sent_data.should match(/214.+/)
    end
  end

  describe "LIST" do
    before do
      timestr = Time.now.strftime("%b %d %H:%M")
      @root_array     = [
        "drwxr-xr-x 1 owner group            0 #{timestr} .",
        "drwxr-xr-x 1 owner group            0 #{timestr} ..",
        "drwxr-xr-x 1 owner group            0 #{timestr} files",
        "-rwxr-xr-x 1 owner group           56 #{timestr} one.txt"
      ]
      @files_array =[
        "drwxr-xr-x 1 owner group            0 #{timestr} .",
        "drwxr-xr-x 1 owner group            0 #{timestr} ..",
        "-rwxr-xr-x 1 owner group           40 #{timestr} two.txt"
      ]
      subject = FTPServer.new(nil)
    end

    it "responds with 530 when called by non-logged in user" do
      subject.reset_sent!
      subject.receive_line("LIST")
      subject.sent_data.should match(/530.+/)
    end

    it "responds with 150 ...425  when called with no data socket" do
      subject = FTPServer.new(nil)
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("LIST")
      subject.sent_data.should match(/150.+425.+/m)
    end

    it "responds with 150 ... 226 when called in the root dir with no param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("LIST")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@root_array)
    end

    it "responds with 150 ... 226 when called in the files dir with no param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("LIST")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@files_array)
    end

    it "responds with 150 ... 226 when called in the files dir with wildcard (LIST *.txt)"

    it "responds with 150 ... 226 when called in the subdir with .. param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("LIST ..")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@root_array)
    end

    it "responds with 150 ... 226 when called in the subdir with / param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("LIST /")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@root_array)
    end

    it "responds with 150 ... 226 when called in the root with files param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("LIST files")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@files_array)
    end

    it "responds with 150 ... 226 when called in the root with files/ param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("LIST files/")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@files_array)
    end

  end

  describe "MKD" do
    it "always responds with 550 (permission denied) when called" do
      subject.reset_sent!
      subject.receive_line("MKD")
      subject.sent_data.should match(/550.+/)
    end
  end

  describe "MODE" do
    it "responds with 553 when called with no param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("MODE")
      subject.sent_data.should match(/553.+/)
    end

    it "always responds with 530 when called by user not logged in" do
      subject.reset_sent!
      subject.receive_line("MODE S")
      subject.sent_data.should match(/530.+/)
    end

    it "always responds with 200 when called with S param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("MODE S")
      subject.sent_data.should match(/200.+/)
    end

    it "always responds with 504 when called with non-S param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("MODE F")
      subject.sent_data.should match(/504.+/)
    end
  end

  describe "NLST" do
    before do
      timestr = Time.now.strftime("%b %d %H:%M")
      @root_array  = %w{ . .. files one.txt }
      @files_array = %w{ . .. two.txt}
      subject = FTPServer.new(nil)
    end

    it "responds with 530 when called by non-logged in user" do
      subject.reset_sent!
      subject.receive_line("NLST")
      subject.sent_data.should match(/530.+/)
    end

    it "responds with 150 ...425  when called with no data socket" do
      subject = FTPServer.new(nil)
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("NLST")
      subject.sent_data.should match(/150.+425.+/m)
    end

    it "responds with 150 ... 226 when called in the root dir with no param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("NLST")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@root_array)
    end

    it "responds with 150 ... 226 when called in the files dir with no param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("NLST")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@files_array)
    end

    it "responds with 150 ... 226 when called in the files dir with wildcard (LIST *.txt)"

    it "responds with 150 ... 226 when called in the subdir with .. param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("NLST ..")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@root_array)
    end

    it "responds with 150 ... 226 when called in the subdir with / param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("NLST /")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@root_array)
    end

    it "responds with 150 ... 226 when called in the root with files param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("NLST files")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@files_array)
    end

    it "responds with 150 ... 226 when called in the root with files/ param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("NLST files/")
      subject.sent_data.should match(/150.+226.+/m)
      subject.oobdata.split(FTPServer::LBRK).should eql(@files_array)
    end

  end

  describe "NOOP" do
    it "always responds with 202 when called" do
      subject.reset_sent!
      subject.receive_line("NOOP")
      subject.sent_data.should match(/200.*/)
    end
  end

  # TODO PASV

  describe "PWD" do
    it "always responds with 550 (permission denied) when called by non-logged in user" do
      subject.reset_sent!
      subject.receive_line("PWD")
      subject.sent_data.should match(/530.+/)
    end

    it "always responds with 257 \"/\" when called from root dir" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("PWD")
      subject.sent_data.strip.should eql("257 \"/\" is the current directory")
    end

    it "always responds with 257 \"/files\" when called from files dir" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.reset_sent!
      subject.receive_line("PWD")
      subject.sent_data.strip.should eql("257 \"/files\" is the current directory")
    end
  end

  describe "PASS" do
    it "responds with 202 when called by logged in user" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("PASS 1234")
      subject.sent_data.should match(/202.+/)
    end

    it "responds with 553 when called with no param" do
      subject.receive_line("USER test")
      subject.reset_sent!
      subject.receive_line("PASS")
      subject.sent_data.should match(/553.+/)
    end

    it "responds with 530 when called without first providing a username" do
      subject.reset_sent!
      subject.receive_line("PASS 1234")
      subject.sent_data.should match(/530.+/)
    end

  end

  describe "RETR" do
    it "responds with 553 when called with no param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("RETR")
      subject.sent_data.should match(/553.+/)
    end

    it "always responds with 530 when called by user not logged in" do
      subject.reset_sent!
      subject.receive_line("RETR blah.txt")
      subject.sent_data.should match(/530.+/)
    end

    it "always responds with 551 when called with an invalid file" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("RETR blah.txt")
      subject.sent_data.should match(/551.+/)
    end

    it "always responds with 150..226 when called with valid file" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("RETR one.txt")
      subject.sent_data.should match(/150.+226.+/m)
    end

    it "always responds with 150..226 when called outside files dir with appropriate param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("RETR files/two.txt")
      subject.sent_data.should match(/150.+226.+/m)
    end
  end

  describe "REST" do
    it "always responds with 500 when called" do
      subject.reset_sent!
      subject.receive_line("REST")
      subject.sent_data.should match(/500.+/)
    end
  end

  describe "RMD" do
    it "always responds with 550 when called" do
      subject.reset_sent!
      subject.receive_line("RMD")
      subject.sent_data.should match(/550.+/)
    end
  end

  describe "RNFR" do
    it "always responds with 550 when called" do
      subject.reset_sent!
      subject.receive_line("RNFR")
      subject.sent_data.should match(/550.+/)
    end
  end

  describe "RNTO" do
    it "always responds with 550 when called" do
      subject.reset_sent!
      subject.receive_line("RNTO")
      subject.sent_data.should match(/550.+/)
    end
  end

  describe "QUIT" do
    it "always responds with 221 when called" do
      subject.reset_sent!
      subject.receive_line("QUIT")
      subject.sent_data.should match(/221.+/)
    end
  end

  describe "SIZE" do
    it "always responds with 530 when called by a non logged in user" do
      subject.reset_sent!
      subject.receive_line("SIZE one.txt")
      subject.sent_data.should match(/530.+/)
    end

    it "always responds with 553 when called with no param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("SIZE")
      subject.sent_data.should match(/553.+/)
    end

    it "always responds with 450 when called with a directory param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("SIZE files")
      subject.sent_data.should match(/450.+/)
    end

    it "always responds with 450 when called with a non-file param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("SIZE blah")
      subject.sent_data.should match(/450.+/)
    end

    it "always responds with 213 when called with a valid file param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD outgoing")
      subject.reset_sent!
      subject.receive_line("SIZE one.txt")
      subject.sent_data.strip.should eql("213 56")
    end

    it "always responds with 213 when called with a valid file param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("SIZE files/two.txt")
      subject.sent_data.strip.should eql("213 40")
    end
  end

  # TODO STOR

  describe "STRU" do
    it "responds with 553 when called with no param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("STRU")
      subject.sent_data.should match(/553.+/)
    end

    it "always responds with 530 when called by user not logged in" do
      subject.reset_sent!
      subject.receive_line("STRU F")
      subject.sent_data.should match(/530.+/)
    end

    it "always responds with 200 when called with F param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("STRU F")
      subject.sent_data.should match(/200.+/)
    end

    it "always responds with 504 when called with non-F param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("STRU S")
      subject.sent_data.should match(/504.+/)
    end
  end

  describe "SYST" do
    it "responds with 530 when called by non-logged in user" do
      subject.reset_sent!
      subject.receive_line("SYST")
      subject.sent_data.should match(/530.+/)
    end

    it "responds with 215 when called by a logged in user" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("SYST")
      subject.sent_data.should match(/215.+/)
      subject.sent_data.include?("UNIX").should be_true
      subject.sent_data.include?("L8").should be_true
    end

  end

  describe "TYPE" do
    it "responds with 530 when called by non-logged in user" do
      subject.reset_sent!
      subject.receive_line("TYPE A")
      subject.sent_data.should match(/530.+/)
    end

    it "responds with 553 when called with no param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("TYPE")
      subject.sent_data.should match(/553.+/)
    end

    it "responds with 200 when with 'A' called by a logged in user" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("TYPE A")
      subject.sent_data.should match(/200.+/)
      subject.sent_data.include?("ASCII").should be_true
    end

    it "responds with 200 when with 'I' called by a logged in user" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("TYPE I")
      subject.sent_data.should match(/200.+/)
      subject.sent_data.include?("binary").should be_true
    end

    it "responds with 500 when called by a logged in user with un unrecognised param" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("TYPE T")
      subject.sent_data.should match(/500.+/)
    end
  end

  describe "USER" do
    it "responds with 331 when called by non-logged in user" do
      subject.reset_sent!
      subject.receive_line("USER jh")
      subject.sent_data.should match(/331.+/)
    end

    it "responds with 500 when called by a logged in user" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("USER test")
      subject.sent_data.should match(/500.+/)
    end
  end

  describe "XCUP" do
    it "responds with 530 if user is not logged in" do
      subject.reset_sent!
      subject.receive_line("XCUP")
      subject.sent_data.should match(/530.*/)
    end

    it "responds with 250 if called from users home" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("XCUP")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/")
    end

    it "responds with 250 if called from files dir" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.reset_sent!
      subject.receive_line("XCUP")
      subject.sent_data.should match(/250.+/)
      subject.name_prefix.should eql("/")
    end
  end

  describe "XPWD" do
    it "always responds with 550 (permission denied) when called by non-logged in user" do
      subject.reset_sent!
      subject.receive_line("XPWD")
      subject.sent_data.should match(/530.+/)
    end

    it "always responds with 257 \"/\" when called from root dir" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.reset_sent!
      subject.receive_line("XPWD")
      subject.sent_data.strip.should eql("257 \"/\" is the current directory")
    end

    it "always responds with 257 \"/files\" when called from incoming dir" do
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("CWD files")
      subject.reset_sent!
      subject.receive_line("XPWD")
      subject.sent_data.strip.should eql("257 \"/files\" is the current directory")
    end
  end

  describe "XRMD" do
    it "always responds with 550 when called" do
      subject.reset_sent!
      subject.receive_line("XRMD")
      subject.sent_data.should match(/550.+/)
    end
  end
end
