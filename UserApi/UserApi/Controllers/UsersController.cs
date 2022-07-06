using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.Linq;
using System;

namespace UserApi.Controllers
{
    [Route("[controller]")]
    [ApiController]
    public class UsersController : Controller
    {
        private readonly List<User> Users = new List<User>()
        {
            new User(1, "John Doe", "johndoe"),
            new User(2, "Jane Doe", "janedoe"),
            new User(3, "Big Lebowsky", "blebowsky"),
        };

        public UsersController() { }

        [HttpGet]
        public IActionResult Get()
        {
            return new OkObjectResult(Users);
        }

        [HttpGet("{id}")]
        public IActionResult Get(int id)
        {
            return new OkObjectResult(Users.Where(x => x.Id == id).FirstOrDefault());
        }

        [HttpPost]
        public IActionResult Create([FromBody] User user)
        {
            Random r = new Random();
            user.Id = r.Next(20);
            return new ObjectResult(user);
        }

        [HttpPut]
        public IActionResult Edit(int id, [FromBody] User user)
        {
            user.Id = id;
            return new ObjectResult(user);
        }

        [HttpDelete]
        public IActionResult Delete(int id)
        {
            return new OkResult();
        }
    }
}
