namespace CarApi
{
    public class Car
    {
        public int Id { get; set; }
        public string Make { get; set; }
        public string Model { get; set; }
        public int Year { get; set; }
        public string Color { get; set; }

        public Car(int id, string make, string model, int year, string color)
        {
            this.Id = id;
            this.Make = make;
            this.Model = model;
            this.Year = year;
            this.Color = color;
        }

        public Car() { }
    }
}
