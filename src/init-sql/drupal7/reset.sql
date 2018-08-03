-- Reset the admin-users password:
-- Set uid 1 username/passsword to admin/admin
UPDATE `users` SET `pass` = '$S$DnyhybQ1LS.tk1SaVb2M67Fo8Hba/2eSYAmXNlTOwMN0I.ionzAq', `name` = 'admin' WHERE `uid` = 1;
-- Reset the temporary files path to /tmp that we know will stay inside the
-- container.
UPDATE `variable` SET `value` = 's:4:"/tmp";' WHERE `name` = 'file_temporary_path';
