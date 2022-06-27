namespace UserApi
{
    public class User
    {
        public int Id { get; set; }
        public string DisplayName { get; set; }
        public string Username { get; set; }

        public User(int id, string displayName, string username)
        {
            this.Id = id;
            this.DisplayName = displayName;
            this.Username = username;
        }

        public User() { }
    }
}
