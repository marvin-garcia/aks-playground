using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.AspNetCore.Mvc;

namespace CarApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CarsController : Controller
    {
        private readonly List<Car> Cars = new List<Car>()
        {
            new Car(1, "Toyota", "Corolla", 2009, "black"),
            new Car(2, "Honda", "Civic", 2018, "Blue"),
            new Car(3, "Kia", "Seltos", 2022, "Yellow"),
        };

        [HttpGet]
        public IActionResult Get()
        {
            return new OkObjectResult(Cars);
        }

        [HttpGet("{id}")]
        public IActionResult Get(int id)
        {
            return new OkObjectResult(Cars.Where(x => x.Id == id).FirstOrDefault());
        }

        [HttpPost]
        public IActionResult Create([FromBody] Car car)
        {
            Random r = new Random();
            car.Id = r.Next(20);
            return new ObjectResult(car);
        }

        [HttpPut]
        public IActionResult Edit(int id, [FromBody] Car car)
        {
            car.Id = id;
            return new ObjectResult(car);
        }

        [HttpDelete]
        public IActionResult Delete(int id)
        {
            return new OkResult();
        }
    }
}
